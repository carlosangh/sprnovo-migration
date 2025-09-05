#!/usr/bin/env python3
"""
SPR Database Migration Manager with Zero-Downtime Support
Executes database migrations without service interruption
"""

import os
import sys
import json
import time
import logging
import asyncio
import hashlib
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass, asdict
from pathlib import Path
from contextlib import asynccontextmanager

import psycopg2
import psycopg2.extras
from psycopg2 import sql
import redis

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('MigrationManager')

@dataclass
class Migration:
    """Database migration definition"""
    id: str
    name: str
    version: str
    sql_content: str
    rollback_sql: Optional[str] = None
    is_breaking: bool = False
    requires_maintenance: bool = False
    estimated_duration: int = 0  # seconds
    dependencies: List[str] = None
    
    def __post_init__(self):
        if self.dependencies is None:
            self.dependencies = []

@dataclass
class MigrationResult:
    """Migration execution result"""
    migration_id: str
    success: bool
    duration: float
    error_message: Optional[str] = None
    affected_rows: int = 0
    rollback_executed: bool = False

class ZeroDowntimeMigrationManager:
    """Manages database migrations with zero-downtime strategies"""
    
    def __init__(self):
        self.db_config = self._get_db_config()
        self.redis_client = self._get_redis_client()
        self.migrations_dir = Path(__file__).parent / "scripts"
        self.lock_key = "spr:migrations:lock"
        self.status_key = "spr:migrations:status"
        self.max_lock_time = 3600  # 1 hour
        
        # Migration strategies
        self.strategies = {
            'online': self._execute_online_migration,
            'shadow_table': self._execute_shadow_table_migration,
            'dual_write': self._execute_dual_write_migration,
            'maintenance': self._execute_maintenance_migration
        }
        
    def _get_db_config(self) -> Dict[str, str]:
        """Get database configuration from environment"""
        return {
            'host': os.getenv('POSTGRES_HOST', 'postgres'),
            'port': int(os.getenv('POSTGRES_PORT', '5432')),
            'database': os.getenv('POSTGRES_DB', 'spr'),
            'user': os.getenv('POSTGRES_USER', 'spr'),
            'password': os.getenv('POSTGRES_PASSWORD', ''),
        }
    
    def _get_redis_client(self) -> redis.Redis:
        """Get Redis client for coordination"""
        redis_url = os.getenv('REDIS_URL', 'redis://redis:6379/0')
        return redis.from_url(redis_url, decode_responses=True)
    
    def get_db_connection(self):
        """Get database connection"""
        return psycopg2.connect(**self.db_config)
    
    @asynccontextmanager
    async def migration_lock(self, operation: str):
        """Distributed lock for migration operations"""
        lock_value = f"{operation}:{datetime.now().isoformat()}"
        lock_acquired = False
        
        try:
            # Try to acquire lock
            if self.redis_client.set(self.lock_key, lock_value, ex=self.max_lock_time, nx=True):
                lock_acquired = True
                logger.info(f"Migration lock acquired for operation: {operation}")
                yield
            else:
                current_lock = self.redis_client.get(self.lock_key)
                raise Exception(f"Migration lock is held by: {current_lock}")
        finally:
            if lock_acquired:
                # Only release lock if we acquired it
                current_value = self.redis_client.get(self.lock_key)
                if current_value == lock_value:
                    self.redis_client.delete(self.lock_key)
                    logger.info(f"Migration lock released for operation: {operation}")
    
    def _ensure_migration_table(self):
        """Ensure migration tracking table exists"""
        with self.get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    CREATE TABLE IF NOT EXISTS schema_migrations (
                        id VARCHAR(255) PRIMARY KEY,
                        name VARCHAR(500) NOT NULL,
                        version VARCHAR(100) NOT NULL,
                        applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        duration_seconds INTEGER DEFAULT 0,
                        checksum VARCHAR(64),
                        rollback_sql TEXT,
                        is_breaking BOOLEAN DEFAULT FALSE,
                        metadata JSONB DEFAULT '{}'
                    )
                """)
                
                # Create index for faster lookups
                cursor.execute("""
                    CREATE INDEX IF NOT EXISTS idx_schema_migrations_version 
                    ON schema_migrations (version)
                """)
                
                # Create index for rollback queries
                cursor.execute("""
                    CREATE INDEX IF NOT EXISTS idx_schema_migrations_applied_at 
                    ON schema_migrations (applied_at)
                """)
                
                conn.commit()
    
    def load_migrations(self) -> List[Migration]:
        """Load all migration files"""
        migrations = []
        
        if not self.migrations_dir.exists():
            logger.warning(f"Migrations directory does not exist: {self.migrations_dir}")
            return migrations
        
        for migration_file in sorted(self.migrations_dir.glob("*.sql")):
            try:
                migration = self._parse_migration_file(migration_file)
                if migration:
                    migrations.append(migration)
            except Exception as e:
                logger.error(f"Failed to load migration {migration_file}: {e}")
        
        return migrations
    
    def _parse_migration_file(self, file_path: Path) -> Optional[Migration]:
        """Parse migration file with metadata"""
        content = file_path.read_text()
        
        # Extract metadata from comments
        metadata = self._extract_migration_metadata(content)
        
        # Generate migration ID from filename
        migration_id = file_path.stem
        
        # Split content into main SQL and rollback SQL
        sql_parts = content.split('-- ROLLBACK:')
        main_sql = sql_parts[0].strip()
        rollback_sql = sql_parts[1].strip() if len(sql_parts) > 1 else None
        
        return Migration(
            id=migration_id,
            name=metadata.get('name', migration_id),
            version=metadata.get('version', '1.0.0'),
            sql_content=main_sql,
            rollback_sql=rollback_sql,
            is_breaking=metadata.get('is_breaking', False),
            requires_maintenance=metadata.get('requires_maintenance', False),
            estimated_duration=metadata.get('estimated_duration', 0),
            dependencies=metadata.get('dependencies', [])
        )
    
    def _extract_migration_metadata(self, content: str) -> Dict[str, Any]:
        """Extract migration metadata from SQL comments"""
        metadata = {}
        
        for line in content.split('\n'):
            if line.strip().startswith('-- META:'):
                try:
                    meta_json = line.replace('-- META:', '').strip()
                    metadata.update(json.loads(meta_json))
                except json.JSONDecodeError:
                    continue
        
        return metadata
    
    def get_applied_migrations(self) -> Dict[str, Dict]:
        """Get list of already applied migrations"""
        with self.get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                cursor.execute("""
                    SELECT id, name, version, applied_at, duration_seconds, 
                           is_breaking, metadata
                    FROM schema_migrations
                    ORDER BY applied_at
                """)
                
                return {row['id']: dict(row) for row in cursor.fetchall()}
    
    def get_pending_migrations(self) -> List[Migration]:
        """Get migrations that need to be applied"""
        all_migrations = self.load_migrations()
        applied_migrations = self.get_applied_migrations()
        
        pending = []
        for migration in all_migrations:
            if migration.id not in applied_migrations:
                # Check dependencies
                missing_deps = [dep for dep in migration.dependencies 
                              if dep not in applied_migrations]
                if missing_deps:
                    logger.warning(f"Migration {migration.id} has missing dependencies: {missing_deps}")
                    continue
                
                pending.append(migration)
        
        return pending
    
    def _calculate_migration_checksum(self, migration: Migration) -> str:
        """Calculate checksum for migration content"""
        content = migration.sql_content + (migration.rollback_sql or "")
        return hashlib.sha256(content.encode()).hexdigest()
    
    async def _execute_online_migration(self, migration: Migration) -> MigrationResult:
        """Execute migration without locking tables (default strategy)"""
        logger.info(f"Executing online migration: {migration.name}")
        
        start_time = time.time()
        error_message = None
        affected_rows = 0
        
        try:
            with self.get_db_connection() as conn:
                with conn.cursor() as cursor:
                    # Execute migration in chunks if it's a large operation
                    if 'UPDATE' in migration.sql_content.upper() or 'DELETE' in migration.sql_content.upper():
                        affected_rows = await self._execute_chunked_operation(cursor, migration.sql_content)
                    else:
                        cursor.execute(migration.sql_content)
                        affected_rows = cursor.rowcount
                    
                    conn.commit()
                    
                    # Record migration
                    self._record_migration(cursor, migration)
                    conn.commit()
            
            duration = time.time() - start_time
            logger.info(f"Online migration {migration.name} completed in {duration:.2f}s")
            
            return MigrationResult(
                migration_id=migration.id,
                success=True,
                duration=duration,
                affected_rows=affected_rows
            )
            
        except Exception as e:
            duration = time.time() - start_time
            error_message = str(e)
            logger.error(f"Online migration {migration.name} failed after {duration:.2f}s: {e}")
            
            return MigrationResult(
                migration_id=migration.id,
                success=False,
                duration=duration,
                error_message=error_message
            )
    
    async def _execute_chunked_operation(self, cursor, sql: str, chunk_size: int = 1000) -> int:
        """Execute large operations in chunks to avoid long locks"""
        total_affected = 0
        
        # This is a simplified chunking strategy
        # In production, you'd want more sophisticated chunking based on the operation
        cursor.execute(sql)
        total_affected = cursor.rowcount
        
        return total_affected
    
    async def _execute_shadow_table_migration(self, migration: Migration) -> MigrationResult:
        """Execute migration using shadow table strategy"""
        logger.info(f"Executing shadow table migration: {migration.name}")
        
        start_time = time.time()
        
        try:
            with self.get_db_connection() as conn:
                with conn.cursor() as cursor:
                    # Create shadow table
                    shadow_sql = migration.sql_content.replace(
                        "CREATE TABLE", "CREATE TABLE shadow_"
                    )
                    cursor.execute(shadow_sql)
                    
                    # Copy data if it's an ALTER TABLE operation
                    if "ALTER TABLE" in migration.sql_content.upper():
                        table_name = self._extract_table_name(migration.sql_content)
                        cursor.execute(f"INSERT INTO shadow_{table_name} SELECT * FROM {table_name}")
                        
                        # Atomic swap
                        cursor.execute(f"BEGIN")
                        cursor.execute(f"DROP TABLE {table_name}")
                        cursor.execute(f"ALTER TABLE shadow_{table_name} RENAME TO {table_name}")
                        cursor.execute(f"COMMIT")
                    
                    conn.commit()
                    
                    # Record migration
                    self._record_migration(cursor, migration)
                    conn.commit()
            
            duration = time.time() - start_time
            logger.info(f"Shadow table migration {migration.name} completed in {duration:.2f}s")
            
            return MigrationResult(
                migration_id=migration.id,
                success=True,
                duration=duration
            )
            
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"Shadow table migration {migration.name} failed: {e}")
            
            return MigrationResult(
                migration_id=migration.id,
                success=False,
                duration=duration,
                error_message=str(e)
            )
    
    async def _execute_dual_write_migration(self, migration: Migration) -> MigrationResult:
        """Execute migration with dual-write strategy for zero downtime"""
        logger.info(f"Executing dual-write migration: {migration.name}")
        
        # This is a placeholder for dual-write strategy
        # Implementation would depend on specific migration requirements
        return await self._execute_online_migration(migration)
    
    async def _execute_maintenance_migration(self, migration: Migration) -> MigrationResult:
        """Execute migration during maintenance window"""
        logger.info(f"Executing maintenance migration: {migration.name}")
        
        # Signal that maintenance mode is required
        self.redis_client.set("spr:maintenance:required", "true", ex=3600)
        
        return await self._execute_online_migration(migration)
    
    def _extract_table_name(self, sql: str) -> str:
        """Extract table name from SQL statement"""
        # Simplified extraction - would need more robust parsing in production
        words = sql.split()
        table_idx = -1
        
        for i, word in enumerate(words):
            if word.upper() == "TABLE":
                table_idx = i + 1
                break
        
        if table_idx > 0 and table_idx < len(words):
            return words[table_idx].strip(';')
        
        return "unknown"
    
    def _record_migration(self, cursor, migration: Migration):
        """Record migration execution in database"""
        checksum = self._calculate_migration_checksum(migration)
        
        cursor.execute("""
            INSERT INTO schema_migrations 
            (id, name, version, checksum, rollback_sql, is_breaking, metadata)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """, (
            migration.id,
            migration.name,
            migration.version,
            checksum,
            migration.rollback_sql,
            migration.is_breaking,
            json.dumps({
                'estimated_duration': migration.estimated_duration,
                'dependencies': migration.dependencies
            })
        ))
    
    async def apply_migrations(self, strategy: str = 'online', dry_run: bool = False) -> List[MigrationResult]:
        """Apply all pending migrations"""
        if strategy not in self.strategies:
            raise ValueError(f"Unknown migration strategy: {strategy}")
        
        pending_migrations = self.get_pending_migrations()
        
        if not pending_migrations:
            logger.info("No pending migrations to apply")
            return []
        
        logger.info(f"Found {len(pending_migrations)} pending migrations")
        
        if dry_run:
            logger.info("DRY RUN - No migrations will be executed")
            for migration in pending_migrations:
                logger.info(f"Would apply migration: {migration.id} - {migration.name}")
            return []
        
        results = []
        strategy_func = self.strategies[strategy]
        
        async with self.migration_lock(f"apply_migrations_{strategy}"):
            self._ensure_migration_table()
            
            for migration in pending_migrations:
                logger.info(f"Applying migration: {migration.id} - {migration.name}")
                
                # Update status in Redis
                self.redis_client.hset(self.status_key, mapping={
                    'current_migration': migration.id,
                    'status': 'applying',
                    'started_at': datetime.now().isoformat()
                })
                
                result = await strategy_func(migration)
                results.append(result)
                
                if not result.success:
                    logger.error(f"Migration {migration.id} failed, stopping execution")
                    
                    # Update status
                    self.redis_client.hset(self.status_key, mapping={
                        'current_migration': migration.id,
                        'status': 'failed',
                        'error': result.error_message,
                        'failed_at': datetime.now().isoformat()
                    })
                    
                    break
                else:
                    logger.info(f"Migration {migration.id} completed successfully")
            
            # Clear status
            self.redis_client.delete(self.status_key)
        
        return results
    
    async def rollback_migration(self, migration_id: str) -> MigrationResult:
        """Rollback a specific migration"""
        logger.info(f"Rolling back migration: {migration_id}")
        
        async with self.migration_lock(f"rollback_{migration_id}"):
            applied_migrations = self.get_applied_migrations()
            
            if migration_id not in applied_migrations:
                raise ValueError(f"Migration {migration_id} was not applied")
            
            migration_record = applied_migrations[migration_id]
            
            start_time = time.time()
            
            try:
                with self.get_db_connection() as conn:
                    with conn.cursor() as cursor:
                        # Get rollback SQL from migration record
                        cursor.execute("""
                            SELECT rollback_sql FROM schema_migrations WHERE id = %s
                        """, (migration_id,))
                        
                        result = cursor.fetchone()
                        if not result or not result[0]:
                            raise Exception(f"No rollback SQL available for migration {migration_id}")
                        
                        rollback_sql = result[0]
                        
                        # Execute rollback
                        cursor.execute(rollback_sql)
                        
                        # Remove migration record
                        cursor.execute("""
                            DELETE FROM schema_migrations WHERE id = %s
                        """, (migration_id,))
                        
                        conn.commit()
                
                duration = time.time() - start_time
                logger.info(f"Migration {migration_id} rolled back successfully in {duration:.2f}s")
                
                return MigrationResult(
                    migration_id=migration_id,
                    success=True,
                    duration=duration,
                    rollback_executed=True
                )
                
            except Exception as e:
                duration = time.time() - start_time
                logger.error(f"Failed to rollback migration {migration_id}: {e}")
                
                return MigrationResult(
                    migration_id=migration_id,
                    success=False,
                    duration=duration,
                    error_message=str(e),
                    rollback_executed=True
                )
    
    def get_migration_status(self) -> Dict[str, Any]:
        """Get current migration status"""
        status = self.redis_client.hgetall(self.status_key)
        
        applied_migrations = self.get_applied_migrations()
        pending_migrations = self.get_pending_migrations()
        
        return {
            'current_operation': status,
            'applied_count': len(applied_migrations),
            'pending_count': len(pending_migrations),
            'latest_applied': max(applied_migrations.values(), 
                                key=lambda x: x['applied_at']) if applied_migrations else None,
            'next_pending': pending_migrations[0].name if pending_migrations else None
        }

# CLI Interface
async def main():
    """Main CLI interface"""
    import argparse
    
    parser = argparse.ArgumentParser(description='SPR Database Migration Manager')
    parser.add_argument('command', choices=['apply', 'rollback', 'status', 'list'], 
                       help='Migration command')
    parser.add_argument('--strategy', choices=['online', 'shadow_table', 'dual_write', 'maintenance'],
                       default='online', help='Migration strategy')
    parser.add_argument('--migration-id', help='Specific migration ID for rollback')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be done')
    
    args = parser.parse_args()
    
    manager = ZeroDowntimeMigrationManager()
    
    try:
        if args.command == 'apply':
            results = await manager.apply_migrations(args.strategy, args.dry_run)
            
            success_count = sum(1 for r in results if r.success)
            print(f"Applied {success_count}/{len(results)} migrations successfully")
            
            for result in results:
                status = "✅" if result.success else "❌"
                print(f"{status} {result.migration_id} ({result.duration:.2f}s)")
                if result.error_message:
                    print(f"   Error: {result.error_message}")
        
        elif args.command == 'rollback':
            if not args.migration_id:
                print("--migration-id is required for rollback")
                sys.exit(1)
            
            result = await manager.rollback_migration(args.migration_id)
            
            status = "✅" if result.success else "❌"
            print(f"{status} Rollback {args.migration_id} ({result.duration:.2f}s)")
            if result.error_message:
                print(f"   Error: {result.error_message}")
        
        elif args.command == 'status':
            status = manager.get_migration_status()
            print(json.dumps(status, indent=2, default=str))
        
        elif args.command == 'list':
            pending = manager.get_pending_migrations()
            applied = manager.get_applied_migrations()
            
            print(f"Applied migrations ({len(applied)}):")
            for migration_id, info in applied.items():
                print(f"  ✅ {migration_id} - {info['name']} (applied: {info['applied_at']})")
            
            print(f"\nPending migrations ({len(pending)}):")
            for migration in pending:
                print(f"  ⏳ {migration.id} - {migration.name}")
    
    except Exception as e:
        logger.error(f"Migration operation failed: {e}")
        sys.exit(1)

if __name__ == '__main__':
    asyncio.run(main())
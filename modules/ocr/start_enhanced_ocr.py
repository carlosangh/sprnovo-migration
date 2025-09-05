#!/usr/bin/env python3
"""
Script para inicializar o sistema OCR Multi-agente Enhanced
"""

import os
import sys
import subprocess
import time
import signal
import logging
from pathlib import Path

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def check_dependencies():
    """Check if required dependencies are available"""
    required_packages = [
        'pytesseract', 'easyocr', 'cv2', 'PIL', 'fitz', 
        'fastapi', 'uvicorn', 'qdrant_client', 'sentence_transformers',
        'torch', 'spacy', 'numpy'
    ]
    
    missing = []
    for package in required_packages:
        try:
            __import__(package)
            logger.info(f"✓ {package} is available")
        except ImportError:
            missing.append(package)
            logger.warning(f"✗ {package} is missing")
    
    if missing:
        logger.error(f"Missing packages: {missing}")
        logger.info("Install missing packages with: pip install " + " ".join(missing))
        return False
    
    return True

def check_services():
    """Check if required services are running"""
    services_status = {}
    
    # Check Qdrant
    try:
        import requests
        response = requests.get("http://localhost:6333/collections", timeout=5)
        if response.status_code == 200:
            services_status['qdrant'] = True
            logger.info("✓ Qdrant is running")
        else:
            services_status['qdrant'] = False
            logger.warning("✗ Qdrant is not responding correctly")
    except Exception as e:
        services_status['qdrant'] = False
        logger.warning(f"✗ Qdrant is not available: {e}")
    
    # Check Tesseract
    try:
        import pytesseract
        version = pytesseract.get_tesseract_version()
        services_status['tesseract'] = True
        logger.info(f"✓ Tesseract version {version} is available")
    except Exception as e:
        services_status['tesseract'] = False
        logger.warning(f"✗ Tesseract is not available: {e}")
    
    return services_status

def create_directories():
    """Create necessary directories"""
    directories = [
        "/opt/spr/_logs",
        "/opt/spr/_uploads", 
        "/tmp/ocr_preprocessing"
    ]
    
    for directory in directories:
        Path(directory).mkdir(parents=True, exist_ok=True)
        logger.info(f"✓ Created directory: {directory}")

def download_models():
    """Download required ML models"""
    logger.info("Downloading/checking ML models...")
    
    try:
        # Download sentence transformer model
        from sentence_transformers import SentenceTransformer
        model = SentenceTransformer('sentence-transformers/all-MiniLM-L6-v2')
        logger.info("✓ SentenceTransformer model ready")
    except Exception as e:
        logger.error(f"✗ Error downloading SentenceTransformer: {e}")
    
    try:
        # Initialize EasyOCR (downloads models on first use)
        import easyocr
        reader = easyocr.Reader(['en', 'pt'])
        logger.info("✓ EasyOCR models ready")
    except Exception as e:
        logger.warning(f"⚠ EasyOCR model download may be needed: {e}")

def start_service():
    """Start the enhanced OCR service"""
    logger.info("Starting Enhanced OCR Multi-Agent Service...")
    
    script_dir = Path(__file__).parent
    service_script = script_dir / "ocr_service_enhanced.py"
    
    if not service_script.exists():
        logger.error(f"Service script not found: {service_script}")
        return None
    
    # Start service with uvicorn
    cmd = [
        sys.executable, "-m", "uvicorn",
        "ocr_service_enhanced:app",
        "--host", "0.0.0.0",
        "--port", "8003",
        "--reload",
        "--log-level", "info"
    ]
    
    try:
        process = subprocess.Popen(
            cmd,
            cwd=script_dir,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        # Wait a moment to check if it started successfully
        time.sleep(3)
        if process.poll() is None:
            logger.info("✓ Enhanced OCR service started successfully")
            logger.info("Service available at: http://localhost:8003")
            logger.info("API docs at: http://localhost:8003/docs")
            return process
        else:
            stdout, stderr = process.communicate()
            logger.error(f"✗ Service failed to start:")
            logger.error(f"STDOUT: {stdout}")
            logger.error(f"STDERR: {stderr}")
            return None
            
    except Exception as e:
        logger.error(f"✗ Error starting service: {e}")
        return None

def monitor_service(process):
    """Monitor the running service"""
    logger.info("Monitoring service... Press Ctrl+C to stop")
    
    def signal_handler(signum, frame):
        logger.info("Received interrupt signal, shutting down...")
        if process:
            process.terminate()
            process.wait()
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    try:
        while True:
            if process.poll() is not None:
                logger.error("Service process has terminated unexpectedly")
                stdout, stderr = process.communicate()
                logger.error(f"STDOUT: {stdout}")
                logger.error(f"STDERR: {stderr}")
                break
            time.sleep(5)
    except KeyboardInterrupt:
        logger.info("Shutting down service...")
        process.terminate()
        process.wait()

def main():
    """Main function"""
    logger.info("=== Enhanced OCR Multi-Agent System Startup ===")
    
    # Step 1: Check dependencies
    logger.info("Step 1: Checking dependencies...")
    if not check_dependencies():
        logger.error("Dependencies check failed. Please install missing packages.")
        sys.exit(1)
    
    # Step 2: Check services
    logger.info("\nStep 2: Checking external services...")
    services = check_services()
    if not services.get('qdrant', False):
        logger.warning("Qdrant is not available. Vector storage will not work.")
    
    # Step 3: Create directories
    logger.info("\nStep 3: Creating directories...")
    create_directories()
    
    # Step 4: Download models
    logger.info("\nStep 4: Checking ML models...")
    download_models()
    
    # Step 5: Start service
    logger.info("\nStep 5: Starting service...")
    process = start_service()
    
    if process:
        logger.info("\n=== Service Started Successfully ===")
        logger.info("Available endpoints:")
        logger.info("- GET  /              - Service info")
        logger.info("- GET  /system/status - System status")
        logger.info("- POST /ocr/enhanced  - Enhanced OCR processing")
        logger.info("- GET  /ocr/search/enhanced - Enhanced search")
        logger.info("\nExample usage:")
        logger.info('curl -X POST "http://localhost:8003/ocr/enhanced" \\')
        logger.info('     -H "Content-Type: application/json" \\')
        logger.info('     -d \'{"file_path": "/path/to/image.png", "strategy": "multi_agent"}\'')
        
        # Monitor service
        monitor_service(process)
    else:
        logger.error("Failed to start service")
        sys.exit(1)

if __name__ == "__main__":
    main()
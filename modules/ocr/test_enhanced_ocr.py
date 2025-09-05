#!/usr/bin/env python3
"""
Script de teste para o sistema OCR Multi-agente Enhanced
"""

import os
import json
import time
import requests
from pathlib import Path
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

BASE_URL = "http://localhost:8003"

def test_service_health():
    """Test if service is running and healthy"""
    try:
        response = requests.get(f"{BASE_URL}/", timeout=10)
        if response.status_code == 200:
            data = response.json()
            logger.info(f"✓ Service is running: {data['service']} v{data['version']}")
            return True
        else:
            logger.error(f"✗ Service responded with status {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        logger.error(f"✗ Service is not accessible: {e}")
        return False

def test_system_status():
    """Test system status endpoint"""
    try:
        response = requests.get(f"{BASE_URL}/system/status", timeout=10)
        if response.status_code == 200:
            status = response.json()
            logger.info("✓ System status retrieved successfully")
            
            # Print key metrics
            stats = status.get('processing_stats', {})
            logger.info(f"  Total processed: {stats.get('total_processed', 0)}")
            logger.info(f"  Success rate: {stats.get('successful', 0)}/{stats.get('total_processed', 0)}")
            
            # Check agent status
            agent_pools = status.get('agent_pools', {})
            for agent_type, agents in agent_pools.items():
                active_count = sum(1 for agent in agents if agent.get('is_active', False))
                logger.info(f"  {agent_type}: {len(agents)} agents ({active_count} active)")
            
            return True
        else:
            logger.error(f"✗ Status check failed with status {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        logger.error(f"✗ Status check failed: {e}")
        return False

def create_test_image():
    """Create a simple test image with text"""
    try:
        from PIL import Image, ImageDraw, ImageFont
        
        # Create test image
        img = Image.new('RGB', (800, 200), color='white')
        draw = ImageDraw.Draw(img)
        
        # Add text
        text = "OCR Multi-Agent Test Document\\nCommodity: CORN\\nPrice: $250.50/bushel\\nDate: 2025-08-21"
        
        try:
            # Try to use a system font
            font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 24)
        except:
            # Fallback to default font
            font = ImageFont.load_default()
        
        # Draw text
        y_offset = 20
        for line in text.split('\\n'):
            draw.text((50, y_offset), line, fill='black', font=font)
            y_offset += 40
        
        # Save test image
        test_image_path = "/tmp/ocr_test_image.png"
        img.save(test_image_path)
        logger.info(f"✓ Created test image: {test_image_path}")
        return test_image_path
        
    except ImportError:
        logger.warning("PIL not available, cannot create test image")
        return None
    except Exception as e:
        logger.error(f"Error creating test image: {e}")
        return None

def test_ocr_processing(image_path, strategy="balanced"):
    """Test OCR processing with different strategies"""
    if not image_path or not os.path.exists(image_path):
        logger.error("Test image not available")
        return False
    
    try:
        payload = {
            "file_path": image_path,
            "strategy": strategy,
            "priority": 1,
            "force_reprocess": True
        }
        
        logger.info(f"Testing OCR with strategy: {strategy}")
        start_time = time.time()
        
        response = requests.post(
            f"{BASE_URL}/ocr/enhanced",
            json=payload,
            timeout=60
        )
        
        processing_time = time.time() - start_time
        
        if response.status_code == 200:
            result = response.json()
            logger.info(f"✓ OCR processing successful in {processing_time:.2f}s")
            logger.info(f"  Task ID: {result.get('task_id', 'N/A')}")
            logger.info(f"  Confidence: {result.get('confidence', 0):.2f}")
            logger.info(f"  Text length: {len(result.get('extracted_text', ''))}")
            logger.info(f"  Strategy used: {result.get('strategy_used', 'N/A')}")
            
            # Show extracted text preview
            text = result.get('extracted_text', '')
            if text:
                preview = text[:200] + "..." if len(text) > 200 else text
                logger.info(f"  Text preview: {preview}")
            
            return True
        else:
            logger.error(f"✗ OCR processing failed with status {response.status_code}")
            logger.error(f"  Response: {response.text}")
            return False
            
    except requests.exceptions.RequestException as e:
        logger.error(f"✗ OCR processing request failed: {e}")
        return False

def test_multi_agent_processing(image_path):
    """Test full multi-agent pipeline"""
    if not image_path or not os.path.exists(image_path):
        logger.error("Test image not available")
        return False
    
    try:
        payload = {
            "file_path": image_path,
            "strategy": "multi_agent",
            "priority": 1,
            "force_reprocess": True
        }
        
        logger.info("Testing full multi-agent pipeline...")
        start_time = time.time()
        
        response = requests.post(
            f"{BASE_URL}/ocr/enhanced",
            json=payload,
            timeout=120  # Multi-agent processing takes longer
        )
        
        processing_time = time.time() - start_time
        
        if response.status_code == 200:
            result = response.json()
            logger.info(f"✓ Multi-agent processing successful in {processing_time:.2f}s")
            logger.info(f"  Task ID: {result.get('task_id', 'N/A')}")
            logger.info(f"  Final confidence: {result.get('confidence', 0):.2f}")
            logger.info(f"  Text extracted: {len(result.get('extracted_text', ''))} characters")
            
            # Show quality metrics if available
            quality = result.get('quality_metrics')
            if quality:
                logger.info(f"  Quality score: {quality}")
            
            # Show content analysis if available
            content = result.get('content_analysis')
            if content:
                logger.info(f"  Content analysis: {json.dumps(content, indent=2)}")
            
            return True
        else:
            logger.error(f"✗ Multi-agent processing failed with status {response.status_code}")
            logger.error(f"  Response: {response.text}")
            return False
            
    except requests.exceptions.RequestException as e:
        logger.error(f"✗ Multi-agent processing request failed: {e}")
        return False

def test_search_functionality():
    """Test enhanced search functionality"""
    try:
        # Test search
        query = "commodity corn price"
        params = {
            "query": query,
            "limit": 5,
            "min_score": 0.5
        }
        
        logger.info(f"Testing search with query: '{query}'")
        
        response = requests.get(
            f"{BASE_URL}/ocr/search/enhanced",
            params=params,
            timeout=30
        )
        
        if response.status_code == 200:
            results = response.json()
            logger.info(f"✓ Search successful")
            logger.info(f"  Found {results.get('total_found', 0)} documents")
            
            # Show first result if available
            if results.get('results'):
                first_result = results['results'][0]
                logger.info(f"  Top result score: {first_result.get('score', 0):.3f}")
                logger.info(f"  Document type: {first_result.get('document_type', 'N/A')}")
                logger.info(f"  Language: {first_result.get('language', 'N/A')}")
            
            return True
        else:
            logger.error(f"✗ Search failed with status {response.status_code}")
            logger.error(f"  Response: {response.text}")
            return False
            
    except requests.exceptions.RequestException as e:
        logger.error(f"✗ Search request failed: {e}")
        return False

def run_performance_test(image_path, iterations=5):
    """Run performance test with multiple iterations"""
    if not image_path or not os.path.exists(image_path):
        logger.error("Test image not available for performance test")
        return False
    
    logger.info(f"Running performance test with {iterations} iterations...")
    
    strategies = ["fast", "balanced", "accurate"]
    results = {}
    
    for strategy in strategies:
        logger.info(f"Testing strategy: {strategy}")
        times = []
        successes = 0
        
        for i in range(iterations):
            payload = {
                "file_path": image_path,
                "strategy": strategy,
                "priority": 1,
                "force_reprocess": True
            }
            
            start_time = time.time()
            try:
                response = requests.post(
                    f"{BASE_URL}/ocr/enhanced",
                    json=payload,
                    timeout=60
                )
                
                processing_time = time.time() - start_time
                
                if response.status_code == 200:
                    times.append(processing_time)
                    successes += 1
                    
            except Exception as e:
                logger.warning(f"  Iteration {i+1} failed: {e}")
        
        if times:
            avg_time = sum(times) / len(times)
            min_time = min(times)
            max_time = max(times)
            
            results[strategy] = {
                "success_rate": successes / iterations,
                "avg_time": avg_time,
                "min_time": min_time,
                "max_time": max_time
            }
            
            logger.info(f"  {strategy}: {successes}/{iterations} successful")
            logger.info(f"  Average time: {avg_time:.2f}s")
            logger.info(f"  Range: {min_time:.2f}s - {max_time:.2f}s")
    
    # Summary
    logger.info("\n=== Performance Summary ===")
    for strategy, metrics in results.items():
        logger.info(f"{strategy:>10}: {metrics['success_rate']*100:5.1f}% success, {metrics['avg_time']:6.2f}s avg")
    
    return len(results) > 0

def main():
    """Run comprehensive test suite"""
    logger.info("=== Enhanced OCR Multi-Agent System Test Suite ===")
    
    test_results = {}
    
    # Test 1: Service Health
    logger.info("\n1. Testing service health...")
    test_results['health'] = test_service_health()
    
    if not test_results['health']:
        logger.error("Service is not available. Stopping tests.")
        return
    
    # Test 2: System Status
    logger.info("\n2. Testing system status...")
    test_results['status'] = test_system_status()
    
    # Test 3: Create test image
    logger.info("\n3. Creating test image...")
    test_image_path = create_test_image()
    
    if test_image_path:
        # Test 4: Basic OCR processing
        logger.info("\n4. Testing basic OCR processing...")
        test_results['ocr_balanced'] = test_ocr_processing(test_image_path, "balanced")
        
        # Test 5: Multi-agent processing
        logger.info("\n5. Testing multi-agent pipeline...")
        test_results['multi_agent'] = test_multi_agent_processing(test_image_path)
        
        # Test 6: Performance test
        logger.info("\n6. Running performance test...")
        test_results['performance'] = run_performance_test(test_image_path, 3)
    else:
        logger.warning("Skipping OCR and performance tests (no test image)")
        test_results['ocr_balanced'] = False
        test_results['multi_agent'] = False
        test_results['performance'] = False
    
    # Test 7: Search functionality
    logger.info("\n7. Testing search functionality...")
    test_results['search'] = test_search_functionality()
    
    # Summary
    logger.info("\n=== Test Results Summary ===")
    passed = sum(1 for result in test_results.values() if result)
    total = len(test_results)
    
    for test_name, result in test_results.items():
        status = "PASS" if result else "FAIL"
        logger.info(f"{test_name:>15}: {status}")
    
    logger.info(f"\nOverall: {passed}/{total} tests passed ({passed/total*100:.1f}%)")
    
    if passed == total:
        logger.info("🎉 All tests passed! System is working correctly.")
    else:
        logger.warning(f"⚠️  {total-passed} test(s) failed. Please check the logs above.")

if __name__ == "__main__":
    main()
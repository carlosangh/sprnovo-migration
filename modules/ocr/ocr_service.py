#!/usr/bin/env python3
"""
Serviço de OCR para processar imagens e PDFs
Sistema de commodities - SPR
"""

import os
import sys
import logging
import json
from typing import List, Dict, Any, Optional, Union
from datetime import datetime
import base64
import tempfile
import hashlib
from pathlib import Path

# OCR Libraries
import pytesseract
import easyocr
from PIL import Image, ImageEnhance, ImageFilter
import fitz  # PyMuPDF
import cv2
import numpy as np

# FastAPI
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# Qdrant integration
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct
from sentence_transformers import SentenceTransformer

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/opt/spr/_logs/ocr_service.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(title="OCR Service", description="Sistema de OCR para commodities", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Constants
UPLOAD_DIR = "/opt/spr/_uploads"
SUPPORTED_IMAGE_FORMATS = {'.jpg', '.jpeg', '.png', '.bmp', '.tiff', '.tif', '.webp'}
SUPPORTED_PDF_FORMAT = {'.pdf'}
MAX_FILE_SIZE = 50 * 1024 * 1024  # 50MB

# Global variables
qdrant_client = None
embedding_model = None
easyocr_reader = None

class OCRResult(BaseModel):
    success: bool
    file_path: str
    extracted_text: str
    confidence: float
    method_used: str
    processing_time: float
    metadata: Dict[str, Any]
    error: Optional[str] = None

class IngestRequest(BaseModel):
    file_path: str
    force_reprocess: bool = False

def initialize_services():
    """Initialize global services"""
    global qdrant_client, embedding_model, easyocr_reader
    
    try:
        # Initialize Qdrant client
        qdrant_client = QdrantClient(host="localhost", port=6333)
        logger.info("Qdrant client initialized")
        
        # Initialize embedding model
        embedding_model = SentenceTransformer('sentence-transformers/all-MiniLM-L6-v2')
        logger.info("Embedding model initialized")
        
        # Initialize EasyOCR
        easyocr_reader = easyocr.Reader(['en', 'pt'])
        logger.info("EasyOCR reader initialized")
        
        # Create collection if not exists
        try:
            collections = qdrant_client.get_collections()
            collection_names = [col.name for col in collections.collections]
            
            if "commodity_documents" not in collection_names:
                qdrant_client.create_collection(
                    collection_name="commodity_documents",
                    vectors_config=VectorParams(size=384, distance=Distance.COSINE),
                )
                logger.info("Created Qdrant collection 'commodity_documents'")
        except Exception as e:
            logger.error(f"Error setting up Qdrant collection: {e}")
            
    except Exception as e:
        logger.error(f"Error initializing services: {e}")
        raise

def preprocess_image(image_path: str) -> np.ndarray:
    """Preprocess image to improve OCR accuracy"""
    try:
        # Read image
        img = cv2.imread(image_path)
        if img is None:
            # Try with PIL
            pil_img = Image.open(image_path)
            img = cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGB2BGR)
        
        # Convert to grayscale
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        
        # Apply denoising
        denoised = cv2.fastNlMeansDenoising(gray)
        
        # Apply adaptive threshold
        thresh = cv2.adaptiveThreshold(
            denoised, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 11, 2
        )
        
        # Remove noise with morphological operations
        kernel = np.ones((1, 1), np.uint8)
        processed = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel)
        
        return processed
    except Exception as e:
        logger.error(f"Error preprocessing image {image_path}: {e}")
        # Return original image if preprocessing fails
        img = cv2.imread(image_path, cv2.IMREAD_GRAYSCALE)
        return img

def extract_text_tesseract(image_path: str) -> Dict[str, Any]:
    """Extract text using Tesseract OCR"""
    try:
        start_time = datetime.now()
        
        # Preprocess image
        processed_img = preprocess_image(image_path)
        
        # Configure Tesseract
        config = r'--oem 3 --psm 6 -l eng+por'
        
        # Extract text
        text = pytesseract.image_to_string(processed_img, config=config)
        
        # Get confidence scores
        data = pytesseract.image_to_data(processed_img, config=config, output_type=pytesseract.Output.DICT)
        confidences = [int(conf) for conf in data['conf'] if int(conf) > 0]
        avg_confidence = sum(confidences) / len(confidences) if confidences else 0
        
        processing_time = (datetime.now() - start_time).total_seconds()
        
        return {
            'text': text.strip(),
            'confidence': avg_confidence / 100.0,  # Convert to 0-1 scale
            'processing_time': processing_time,
            'method': 'tesseract'
        }
    except Exception as e:
        logger.error(f"Tesseract OCR error for {image_path}: {e}")
        return {'text': '', 'confidence': 0.0, 'processing_time': 0.0, 'method': 'tesseract', 'error': str(e)}

def extract_text_easyocr(image_path: str) -> Dict[str, Any]:
    """Extract text using EasyOCR"""
    try:
        start_time = datetime.now()
        
        # Extract text with EasyOCR
        results = easyocr_reader.readtext(image_path)
        
        # Combine all text
        text_parts = []
        confidences = []
        
        for (bbox, text, confidence) in results:
            text_parts.append(text)
            confidences.append(confidence)
        
        combined_text = ' '.join(text_parts)
        avg_confidence = sum(confidences) / len(confidences) if confidences else 0
        
        processing_time = (datetime.now() - start_time).total_seconds()
        
        return {
            'text': combined_text.strip(),
            'confidence': avg_confidence,
            'processing_time': processing_time,
            'method': 'easyocr'
        }
    except Exception as e:
        logger.error(f"EasyOCR error for {image_path}: {e}")
        return {'text': '', 'confidence': 0.0, 'processing_time': 0.0, 'method': 'easyocr', 'error': str(e)}

def extract_text_from_pdf(pdf_path: str) -> Dict[str, Any]:
    """Extract text from PDF, including OCR for image-based pages"""
    try:
        start_time = datetime.now()
        
        doc = fitz.open(pdf_path)
        all_text = []
        total_confidence = 0
        processed_pages = 0
        
        for page_num in range(doc.page_count):
            page = doc.load_page(page_num)
            
            # Try to extract text directly first
            direct_text = page.get_text().strip()
            
            if len(direct_text) > 100:  # If we have substantial direct text
                all_text.append(direct_text)
                total_confidence += 0.95  # High confidence for direct text extraction
                processed_pages += 1
            else:
                # Convert page to image and OCR
                try:
                    pix = page.get_pixmap(matrix=fitz.Matrix(2, 2))  # High resolution
                    img_data = pix.tobytes("png")
                    
                    # Save to temporary file for OCR
                    with tempfile.NamedTemporaryFile(suffix='.png', delete=False) as tmp_file:
                        tmp_file.write(img_data)
                        tmp_path = tmp_file.name
                    
                    # Try EasyOCR first, then Tesseract as backup
                    ocr_result = extract_text_easyocr(tmp_path)
                    if ocr_result['confidence'] < 0.5:  # If EasyOCR confidence is low, try Tesseract
                        tesseract_result = extract_text_tesseract(tmp_path)
                        if tesseract_result['confidence'] > ocr_result['confidence']:
                            ocr_result = tesseract_result
                    
                    if ocr_result['text']:
                        all_text.append(ocr_result['text'])
                        total_confidence += ocr_result['confidence']
                        processed_pages += 1
                    
                    # Clean up temp file
                    os.unlink(tmp_path)
                    
                except Exception as e:
                    logger.error(f"Error OCRing page {page_num} of {pdf_path}: {e}")
        
        doc.close()
        
        combined_text = '\n\n'.join(all_text)
        avg_confidence = total_confidence / processed_pages if processed_pages > 0 else 0
        processing_time = (datetime.now() - start_time).total_seconds()
        
        return {
            'text': combined_text.strip(),
            'confidence': avg_confidence,
            'processing_time': processing_time,
            'method': 'pdf_hybrid',
            'pages_processed': processed_pages
        }
        
    except Exception as e:
        logger.error(f"PDF processing error for {pdf_path}: {e}")
        return {'text': '', 'confidence': 0.0, 'processing_time': 0.0, 'method': 'pdf_hybrid', 'error': str(e)}

def create_file_hash(file_path: str) -> str:
    """Create hash of file for deduplication"""
    hasher = hashlib.md5()
    with open(file_path, 'rb') as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hasher.update(chunk)
    return hasher.hexdigest()

def save_to_qdrant(text: str, metadata: Dict[str, Any]) -> bool:
    """Save extracted text to Qdrant vector database"""
    try:
        if not text.strip():
            logger.warning("Empty text, skipping Qdrant save")
            return False
            
        # Create embedding
        embedding = embedding_model.encode(text).tolist()
        
        # Create point
        point = PointStruct(
            id=metadata.get('file_hash', str(hash(text))),
            vector=embedding,
            payload={
                'text': text,
                'file_path': metadata.get('file_path', ''),
                'file_name': metadata.get('file_name', ''),
                'file_type': metadata.get('file_type', ''),
                'extracted_at': datetime.now().isoformat(),
                'ocr_method': metadata.get('ocr_method', ''),
                'confidence': metadata.get('confidence', 0.0),
                'processing_time': metadata.get('processing_time', 0.0),
                'file_size': metadata.get('file_size', 0),
                'file_hash': metadata.get('file_hash', ''),
            }
        )
        
        # Upsert to collection
        qdrant_client.upsert(
            collection_name="commodity_documents",
            points=[point]
        )
        
        logger.info(f"Successfully saved document to Qdrant: {metadata.get('file_name', 'unknown')}")
        return True
        
    except Exception as e:
        logger.error(f"Error saving to Qdrant: {e}")
        return False

@app.on_event("startup")
async def startup_event():
    """Initialize services on startup"""
    initialize_services()
    logger.info("OCR Service started successfully")

@app.get("/")
async def root():
    return {
        "service": "OCR Service", 
        "status": "running", 
        "timestamp": datetime.now().isoformat(),
        "version": "1.0.0"
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    status = "healthy"
    services = {}
    
    # Check Qdrant
    try:
        qdrant_client.get_collections()
        services["qdrant"] = "healthy"
    except Exception as e:
        services["qdrant"] = f"error: {str(e)}"
        status = "unhealthy"
    
    # Check embedding model
    try:
        embedding_model.encode("test")
        services["embedding_model"] = "healthy"
    except Exception as e:
        services["embedding_model"] = f"error: {str(e)}"
        status = "unhealthy"
    
    # Check OCR
    services["tesseract"] = "healthy" if pytesseract.get_tesseract_version() else "error"
    services["easyocr"] = "healthy" if easyocr_reader else "error"
    
    return {
        "status": status,
        "services": services,
        "timestamp": datetime.now().isoformat()
    }

@app.post("/ocr/process_file")
async def process_file(request: IngestRequest):
    """Process a single file for OCR"""
    try:
        file_path = request.file_path
        
        # Validate file exists
        if not os.path.exists(file_path):
            raise HTTPException(status_code=404, detail=f"File not found: {file_path}")
        
        # Get file info
        file_stat = os.stat(file_path)
        file_size = file_stat.st_size
        file_name = os.path.basename(file_path)
        file_ext = Path(file_path).suffix.lower()
        
        if file_size > MAX_FILE_SIZE:
            raise HTTPException(status_code=413, detail=f"File too large: {file_size} bytes")
        
        # Create file hash for deduplication
        file_hash = create_file_hash(file_path)
        
        # Check if already processed (unless forced)
        if not request.force_reprocess:
            try:
                search_result = qdrant_client.scroll(
                    collection_name="commodity_documents",
                    scroll_filter={"must": [{"key": "file_hash", "match": {"value": file_hash}}]},
                    limit=1
                )
                if search_result[0]:  # If document already exists
                    logger.info(f"File already processed: {file_name}")
                    existing_doc = search_result[0][0].payload
                    return OCRResult(
                        success=True,
                        file_path=file_path,
                        extracted_text=existing_doc['text'],
                        confidence=existing_doc['confidence'],
                        method_used=f"{existing_doc['ocr_method']} (cached)",
                        processing_time=0.0,
                        metadata={
                            'file_name': file_name,
                            'file_size': file_size,
                            'cached': True,
                            'original_extraction': existing_doc['extracted_at']
                        }
                    )
            except Exception as e:
                logger.warning(f"Error checking for existing document: {e}")
        
        # Process based on file type
        start_time = datetime.now()
        
        if file_ext in SUPPORTED_IMAGE_FORMATS:
            # Try multiple OCR methods and pick the best result
            tesseract_result = extract_text_tesseract(file_path)
            easyocr_result = extract_text_easyocr(file_path)
            
            # Choose best result based on confidence and text length
            if (easyocr_result['confidence'] > tesseract_result['confidence'] and 
                len(easyocr_result['text']) > len(tesseract_result['text']) * 0.8):
                result = easyocr_result
            else:
                result = tesseract_result
                
        elif file_ext in SUPPORTED_PDF_FORMAT:
            result = extract_text_from_pdf(file_path)
        else:
            raise HTTPException(status_code=400, detail=f"Unsupported file format: {file_ext}")
        
        total_processing_time = (datetime.now() - start_time).total_seconds()
        
        # Prepare metadata
        metadata = {
            'file_path': file_path,
            'file_name': file_name,
            'file_type': file_ext,
            'file_size': file_size,
            'file_hash': file_hash,
            'ocr_method': result['method'],
            'confidence': result['confidence'],
            'processing_time': total_processing_time,
        }
        
        # Save to Qdrant if extraction was successful
        qdrant_success = False
        if result['text'].strip():
            qdrant_success = save_to_qdrant(result['text'], metadata)
        
        # Prepare response
        return OCRResult(
            success=bool(result['text'].strip()),
            file_path=file_path,
            extracted_text=result['text'],
            confidence=result['confidence'],
            method_used=result['method'],
            processing_time=total_processing_time,
            metadata={
                'file_name': file_name,
                'file_size': file_size,
                'file_type': file_ext,
                'qdrant_saved': qdrant_success,
                'text_length': len(result['text']),
                **metadata
            },
            error=result.get('error')
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error processing file {request.file_path}: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/ocr/upload")
async def upload_and_process(file: UploadFile = File(...)):
    """Upload and immediately process file"""
    try:
        # Validate file
        if not file.filename:
            raise HTTPException(status_code=400, detail="No filename provided")
        
        file_ext = Path(file.filename).suffix.lower()
        if file_ext not in (SUPPORTED_IMAGE_FORMATS | SUPPORTED_PDF_FORMAT):
            raise HTTPException(status_code=400, detail=f"Unsupported file format: {file_ext}")
        
        # Create upload path
        now = datetime.now()
        upload_subdir = f"{now.year}/{now.month:02d}/{now.day:02d}"
        upload_dir = Path(UPLOAD_DIR) / upload_subdir
        upload_dir.mkdir(parents=True, exist_ok=True)
        
        # Save file
        timestamp = int(now.timestamp() * 1000)
        safe_filename = "".join(c for c in file.filename if c.isalnum() or c in '._-')[:100]
        saved_filename = f"{timestamp}__{safe_filename}"
        file_path = upload_dir / saved_filename
        
        content = await file.read()
        with open(file_path, "wb") as f:
            f.write(content)
        
        # Process file
        result = await process_file(IngestRequest(file_path=str(file_path)))
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error uploading and processing file: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/ocr/search")
async def search_documents(query: str, limit: int = 10):
    """Search documents in Qdrant"""
    try:
        if not query.strip():
            raise HTTPException(status_code=400, detail="Query cannot be empty")
        
        # Create query embedding
        query_embedding = embedding_model.encode(query).tolist()
        
        # Search in Qdrant
        search_result = qdrant_client.search(
            collection_name="commodity_documents",
            query_vector=query_embedding,
            limit=limit
        )
        
        results = []
        for hit in search_result:
            results.append({
                "score": hit.score,
                "text": hit.payload["text"][:500] + "..." if len(hit.payload["text"]) > 500 else hit.payload["text"],
                "file_name": hit.payload["file_name"],
                "file_path": hit.payload["file_path"],
                "extracted_at": hit.payload["extracted_at"],
                "confidence": hit.payload["confidence"],
                "method": hit.payload["ocr_method"]
            })
        
        return {
            "query": query,
            "results": results,
            "total_found": len(results)
        }
        
    except Exception as e:
        logger.error(f"Error searching documents: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8002)
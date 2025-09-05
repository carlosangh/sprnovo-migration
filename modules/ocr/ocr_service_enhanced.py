#!/usr/bin/env python3
"""
Serviço de OCR Enhanced com Sistema Multi-agente
Sistema de commodities - SPR
Versão 2.0 - Multi-Agent OCR System
"""

import os
import sys
import logging
import json
import asyncio
from typing import List, Dict, Any, Optional, Union, Tuple
from datetime import datetime
from dataclasses import dataclass, asdict
import base64
import tempfile
import hashlib
from pathlib import Path
import concurrent.futures
from enum import Enum
from abc import ABC, abstractmethod
import time
import threading
from queue import Queue, Empty

# OCR Libraries
import pytesseract
import easyocr
from PIL import Image, ImageEnhance, ImageFilter, ImageOps
import fitz  # PyMuPDF
import cv2
import numpy as np

# ML/AI Libraries
from transformers import pipeline, AutoTokenizer, AutoModel
import torch
import spacy
import openai
from openai import OpenAI

# FastAPI
from fastapi import FastAPI, File, UploadFile, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# Qdrant integration
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct, Filter
from sentence_transformers import SentenceTransformer

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/opt/spr/_logs/ocr_enhanced.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class AgentType(Enum):
    COORDINATOR = "coordinator"
    OCR_SPECIALIST = "ocr_specialist"
    PREPROCESSOR = "preprocessor"
    QUALITY_ASSESSOR = "quality_assessor"
    CONTENT_ANALYZER = "content_analyzer"
    VECTORIZER = "vectorizer"
    SMART_ANALYST = "smart_analyst"

class ProcessingStrategy(Enum):
    FAST = "fast"
    BALANCED = "balanced"
    ACCURATE = "accurate"
    MULTI_AGENT = "multi_agent"

@dataclass
class ProcessingTask:
    task_id: str
    file_path: str
    strategy: ProcessingStrategy
    priority: int = 1
    metadata: Dict[str, Any] = None
    created_at: datetime = None
    
    def __post_init__(self):
        if self.created_at is None:
            self.created_at = datetime.now()
        if self.metadata is None:
            self.metadata = {}

@dataclass
class AgentResult:
    agent_id: str
    agent_type: AgentType
    task_id: str
    success: bool
    data: Dict[str, Any]
    processing_time: float
    error: Optional[str] = None
    confidence: float = 0.0

class BaseAgent(ABC):
    """Base class for all agents"""
    
    def __init__(self, agent_id: str, agent_type: AgentType):
        self.agent_id = agent_id
        self.agent_type = agent_type
        self.is_active = False
        self.processed_count = 0
        self.last_activity = None
        
    @abstractmethod
    async def process(self, task: ProcessingTask) -> AgentResult:
        pass
    
    def get_status(self) -> Dict[str, Any]:
        return {
            'agent_id': self.agent_id,
            'agent_type': self.agent_type.value,
            'is_active': self.is_active,
            'processed_count': self.processed_count,
            'last_activity': self.last_activity.isoformat() if self.last_activity else None
        }

class PreprocessorAgent(BaseAgent):
    """Agent responsável pelo pré-processamento de imagens"""
    
    def __init__(self, agent_id: str):
        super().__init__(agent_id, AgentType.PREPROCESSOR)
        
    async def process(self, task: ProcessingTask) -> AgentResult:
        start_time = time.time()
        self.is_active = True
        self.last_activity = datetime.now()
        
        try:
            file_path = task.file_path
            file_ext = Path(file_path).suffix.lower()
            
            if file_ext in {'.jpg', '.jpeg', '.png', '.bmp', '.tiff', '.tif', '.webp'}:
                processed_images = self._preprocess_image_variants(file_path)
                
                result = AgentResult(
                    agent_id=self.agent_id,
                    agent_type=self.agent_type,
                    task_id=task.task_id,
                    success=True,
                    data={'processed_images': processed_images},
                    processing_time=time.time() - start_time,
                    confidence=0.95
                )
            else:
                result = AgentResult(
                    agent_id=self.agent_id,
                    agent_type=self.agent_type,
                    task_id=task.task_id,
                    success=False,
                    data={},
                    processing_time=time.time() - start_time,
                    error="File type not supported for preprocessing"
                )
                
        except Exception as e:
            logger.error(f"PreprocessorAgent {self.agent_id} error: {e}")
            result = AgentResult(
                agent_id=self.agent_id,
                agent_type=self.agent_type,
                task_id=task.task_id,
                success=False,
                data={},
                processing_time=time.time() - start_time,
                error=str(e)
            )
        finally:
            self.is_active = False
            self.processed_count += 1
            
        return result
    
    def _preprocess_image_variants(self, image_path: str) -> List[str]:
        """Create multiple preprocessed variants of the image"""
        variants = []
        
        try:
            # Read original image
            img = cv2.imread(image_path)
            if img is None:
                pil_img = Image.open(image_path)
                img = cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGB2BGR)
            
            base_name = Path(image_path).stem
            temp_dir = Path('/tmp/ocr_preprocessing')
            temp_dir.mkdir(exist_ok=True)
            
            # Variant 1: High contrast + denoising
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
            denoised = cv2.fastNlMeansDenoising(gray)
            contrast = cv2.convertScaleAbs(denoised, alpha=1.5, beta=30)
            variant1_path = temp_dir / f"{base_name}_variant1.png"
            cv2.imwrite(str(variant1_path), contrast)
            variants.append(str(variant1_path))
            
            # Variant 2: Adaptive threshold
            thresh = cv2.adaptiveThreshold(
                gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 11, 2
            )
            variant2_path = temp_dir / f"{base_name}_variant2.png"
            cv2.imwrite(str(variant2_path), thresh)
            variants.append(str(variant2_path))
            
            # Variant 3: Morphological operations
            kernel = np.ones((2, 2), np.uint8)
            morph = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel)
            variant3_path = temp_dir / f"{base_name}_variant3.png"
            cv2.imwrite(str(variant3_path), morph)
            variants.append(str(variant3_path))
            
            # Variant 4: Histogram equalization
            equalized = cv2.equalizeHist(gray)
            variant4_path = temp_dir / f"{base_name}_variant4.png"
            cv2.imwrite(str(variant4_path), equalized)
            variants.append(str(variant4_path))
            
            # Original for comparison
            original_path = temp_dir / f"{base_name}_original.png"
            cv2.imwrite(str(original_path), img)
            variants.append(str(original_path))
            
        except Exception as e:
            logger.error(f"Error creating image variants: {e}")
            
        return variants

class OCRSpecialistAgent(BaseAgent):
    """Agent especialista em OCR com múltiplas engines"""
    
    def __init__(self, agent_id: str):
        super().__init__(agent_id, AgentType.OCR_SPECIALIST)
        self.easyocr_reader = None
        self._initialize_ocr_engines()
        
    def _initialize_ocr_engines(self):
        try:
            self.easyocr_reader = easyocr.Reader(['en', 'pt'], gpu=torch.cuda.is_available())
        except Exception as e:
            logger.error(f"Error initializing EasyOCR: {e}")
    
    async def process(self, task: ProcessingTask) -> AgentResult:
        start_time = time.time()
        self.is_active = True
        self.last_activity = datetime.now()
        
        try:
            file_path = task.file_path
            preprocessed_images = task.metadata.get('processed_images', [file_path])
            
            # Process all variants in parallel
            with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
                futures = []
                for img_path in preprocessed_images:
                    futures.append(executor.submit(self._extract_text_multi_engine, img_path))
                
                results = [f.result() for f in futures]
            
            # Find best result
            best_result = max(results, key=lambda x: x.get('confidence', 0) * len(x.get('text', '')))
            
            result = AgentResult(
                agent_id=self.agent_id,
                agent_type=self.agent_type,
                task_id=task.task_id,
                success=True,
                data={
                    'best_result': best_result,
                    'all_results': results,
                    'variants_processed': len(preprocessed_images)
                },
                processing_time=time.time() - start_time,
                confidence=best_result.get('confidence', 0)
            )
            
        except Exception as e:
            logger.error(f"OCRSpecialistAgent {self.agent_id} error: {e}")
            result = AgentResult(
                agent_id=self.agent_id,
                agent_type=self.agent_type,
                task_id=task.task_id,
                success=False,
                data={},
                processing_time=time.time() - start_time,
                error=str(e)
            )
        finally:
            self.is_active = False
            self.processed_count += 1
            
        return result
    
    def _extract_text_multi_engine(self, image_path: str) -> Dict[str, Any]:
        """Extract text using multiple OCR engines"""
        results = []
        
        # Tesseract
        try:
            config = r'--oem 3 --psm 6 -l eng+por'
            img = cv2.imread(image_path, cv2.IMREAD_GRAYSCALE)
            text = pytesseract.image_to_string(img, config=config)
            
            data = pytesseract.image_to_data(img, config=config, output_type=pytesseract.Output.DICT)
            confidences = [int(conf) for conf in data['conf'] if int(conf) > 0]
            avg_confidence = sum(confidences) / len(confidences) if confidences else 0
            
            results.append({
                'engine': 'tesseract',
                'text': text.strip(),
                'confidence': avg_confidence / 100.0,
                'image_path': image_path
            })
        except Exception as e:
            logger.error(f"Tesseract error: {e}")
        
        # EasyOCR
        if self.easyocr_reader:
            try:
                ocr_results = self.easyocr_reader.readtext(image_path)
                text_parts = []
                confidences = []
                
                for (bbox, text, confidence) in ocr_results:
                    text_parts.append(text)
                    confidences.append(confidence)
                
                combined_text = ' '.join(text_parts)
                avg_confidence = sum(confidences) / len(confidences) if confidences else 0
                
                results.append({
                    'engine': 'easyocr',
                    'text': combined_text.strip(),
                    'confidence': avg_confidence,
                    'image_path': image_path
                })
            except Exception as e:
                logger.error(f"EasyOCR error: {e}")
        
        # Return best result
        if results:
            return max(results, key=lambda x: x['confidence'] * len(x['text']))
        else:
            return {'engine': 'none', 'text': '', 'confidence': 0.0, 'image_path': image_path}

class QualityAssessorAgent(BaseAgent):
    """Agent responsável por avaliar qualidade do OCR"""
    
    def __init__(self, agent_id: str):
        super().__init__(agent_id, AgentType.QUALITY_ASSESSOR)
        
    async def process(self, task: ProcessingTask) -> AgentResult:
        start_time = time.time()
        self.is_active = True
        self.last_activity = datetime.now()
        
        try:
            ocr_data = task.metadata.get('ocr_results', {})
            best_result = ocr_data.get('best_result', {})
            all_results = ocr_data.get('all_results', [])
            
            quality_score = self._assess_quality(best_result, all_results)
            recommendations = self._generate_recommendations(quality_score, best_result)
            
            result = AgentResult(
                agent_id=self.agent_id,
                agent_type=self.agent_type,
                task_id=task.task_id,
                success=True,
                data={
                    'quality_score': quality_score,
                    'recommendations': recommendations,
                    'text_metrics': self._calculate_text_metrics(best_result.get('text', ''))
                },
                processing_time=time.time() - start_time,
                confidence=quality_score
            )
            
        except Exception as e:
            logger.error(f"QualityAssessorAgent {self.agent_id} error: {e}")
            result = AgentResult(
                agent_id=self.agent_id,
                agent_type=self.agent_type,
                task_id=task.task_id,
                success=False,
                data={},
                processing_time=time.time() - start_time,
                error=str(e)
            )
        finally:
            self.is_active = False
            self.processed_count += 1
            
        return result
    
    def _assess_quality(self, best_result: Dict, all_results: List[Dict]) -> float:
        """Assess OCR quality based on multiple factors"""
        if not best_result:
            return 0.0
            
        factors = []
        
        # Confidence score
        confidence = best_result.get('confidence', 0)
        factors.append(confidence * 0.4)
        
        # Text length (longer text usually means better extraction)
        text = best_result.get('text', '')
        length_score = min(len(text) / 1000, 1.0) * 0.2
        factors.append(length_score)
        
        # Consistency across variants
        if len(all_results) > 1:
            consistency = self._calculate_consistency(all_results)
            factors.append(consistency * 0.2)
        
        # Text characteristics (punctuation, structure)
        structure_score = self._evaluate_text_structure(text)
        factors.append(structure_score * 0.2)
        
        return sum(factors)
    
    def _calculate_consistency(self, results: List[Dict]) -> float:
        """Calculate consistency between different OCR results"""
        if len(results) < 2:
            return 1.0
            
        texts = [r.get('text', '').lower() for r in results]
        # Simple word overlap calculation
        all_words = set()
        for text in texts:
            all_words.update(text.split())
        
        if not all_words:
            return 0.0
            
        common_words = set(texts[0].split())
        for text in texts[1:]:
            common_words &= set(text.split())
            
        return len(common_words) / len(all_words) if all_words else 0.0
    
    def _evaluate_text_structure(self, text: str) -> float:
        """Evaluate text structure quality"""
        if not text:
            return 0.0
            
        score = 0.0
        
        # Check for punctuation
        if any(p in text for p in '.!?'):
            score += 0.3
            
        # Check for proper capitalization
        sentences = text.split('.')
        capitalized = sum(1 for s in sentences if s.strip() and s.strip()[0].isupper())
        score += (capitalized / len(sentences)) * 0.3 if sentences else 0
        
        # Check for reasonable word lengths
        words = text.split()
        if words:
            avg_word_length = sum(len(w) for w in words) / len(words)
            if 3 <= avg_word_length <= 8:  # Reasonable average
                score += 0.4
        
        return min(score, 1.0)
    
    def _calculate_text_metrics(self, text: str) -> Dict[str, Any]:
        """Calculate various text metrics"""
        if not text:
            return {}
            
        words = text.split()
        return {
            'character_count': len(text),
            'word_count': len(words),
            'sentence_count': len([s for s in text.split('.') if s.strip()]),
            'average_word_length': sum(len(w) for w in words) / len(words) if words else 0,
            'uppercase_ratio': sum(1 for c in text if c.isupper()) / len(text) if text else 0,
            'digit_ratio': sum(1 for c in text if c.isdigit()) / len(text) if text else 0,
            'punctuation_count': sum(1 for c in text if c in '.,!?;:')
        }
    
    def _generate_recommendations(self, quality_score: float, result: Dict) -> List[str]:
        """Generate recommendations based on quality assessment"""
        recommendations = []
        
        if quality_score < 0.5:
            recommendations.append("Quality is low - consider manual review")
            recommendations.append("Try different preprocessing techniques")
            
        if result.get('confidence', 0) < 0.6:
            recommendations.append("Low OCR confidence - verify critical information")
            
        text = result.get('text', '')
        if len(text) < 50:
            recommendations.append("Very short text extracted - image may have quality issues")
            
        return recommendations

class ContentAnalyzerAgent(BaseAgent):
    """Agent responsável por análise de conteúdo e extração de informações estruturadas"""
    
    def __init__(self, agent_id: str):
        super().__init__(agent_id, AgentType.CONTENT_ANALYZER)
        self.nlp = None
        self._initialize_nlp()
        
    def _initialize_nlp(self):
        try:
            # Try to load spaCy model
            self.nlp = spacy.load("en_core_web_sm")
        except IOError:
            logger.warning("spaCy model not found - using basic analysis")
    
    async def process(self, task: ProcessingTask) -> AgentResult:
        start_time = time.time()
        self.is_active = True
        self.last_activity = datetime.now()
        
        try:
            text = task.metadata.get('extracted_text', '')
            
            analysis = {
                'entities': self._extract_entities(text),
                'keywords': self._extract_keywords(text),
                'document_type': self._classify_document_type(text),
                'language': self._detect_language(text),
                'structured_data': self._extract_structured_data(text)
            }
            
            result = AgentResult(
                agent_id=self.agent_id,
                agent_type=self.agent_type,
                task_id=task.task_id,
                success=True,
                data=analysis,
                processing_time=time.time() - start_time,
                confidence=0.8
            )
            
        except Exception as e:
            logger.error(f"ContentAnalyzerAgent {self.agent_id} error: {e}")
            result = AgentResult(
                agent_id=self.agent_id,
                agent_type=self.agent_type,
                task_id=task.task_id,
                success=False,
                data={},
                processing_time=time.time() - start_time,
                error=str(e)
            )
        finally:
            self.is_active = False
            self.processed_count += 1
            
        return result
    
    def _extract_entities(self, text: str) -> List[Dict[str, str]]:
        """Extract named entities from text"""
        entities = []
        
        if self.nlp and text:
            try:
                doc = self.nlp(text)
                for ent in doc.ents:
                    entities.append({
                        'text': ent.text,
                        'label': ent.label_,
                        'description': spacy.explain(ent.label_) or ent.label_
                    })
            except Exception as e:
                logger.error(f"Entity extraction error: {e}")
        
        return entities
    
    def _extract_keywords(self, text: str) -> List[str]:
        """Extract keywords from text"""
        if not text:
            return []
            
        # Simple keyword extraction based on frequency
        words = text.lower().split()
        word_freq = {}
        
        for word in words:
            if len(word) > 3 and word.isalpha():
                word_freq[word] = word_freq.get(word, 0) + 1
        
        # Return top 10 most frequent words
        return sorted(word_freq.keys(), key=lambda x: word_freq[x], reverse=True)[:10]
    
    def _classify_document_type(self, text: str) -> str:
        """Classify document type based on content"""
        if not text:
            return "unknown"
            
        text_lower = text.lower()
        
        if any(word in text_lower for word in ['invoice', 'bill', 'receipt', 'payment']):
            return "financial_document"
        elif any(word in text_lower for word in ['contract', 'agreement', 'terms']):
            return "legal_document"
        elif any(word in text_lower for word in ['report', 'analysis', 'summary']):
            return "report"
        elif any(word in text_lower for word in ['commodity', 'grain', 'corn', 'wheat', 'soy']):
            return "commodity_document"
        else:
            return "general_document"
    
    def _detect_language(self, text: str) -> str:
        """Simple language detection"""
        if not text:
            return "unknown"
            
        # Simple heuristic based on common words
        portuguese_indicators = ['de', 'da', 'do', 'em', 'com', 'para', 'por', 'uma', 'um']
        english_indicators = ['the', 'and', 'of', 'to', 'in', 'for', 'with', 'on', 'at']
        
        text_lower = text.lower()
        pt_count = sum(1 for word in portuguese_indicators if word in text_lower)
        en_count = sum(1 for word in english_indicators if word in text_lower)
        
        if pt_count > en_count:
            return "portuguese"
        elif en_count > pt_count:
            return "english"
        else:
            return "mixed"
    
    def _extract_structured_data(self, text: str) -> Dict[str, Any]:
        """Extract structured data like dates, numbers, etc."""
        import re
        
        data = {
            'dates': [],
            'numbers': [],
            'currencies': [],
            'percentages': []
        }
        
        if not text:
            return data
        
        # Extract dates
        date_patterns = [
            r'\d{1,2}/\d{1,2}/\d{4}',
            r'\d{1,2}-\d{1,2}-\d{4}',
            r'\d{4}-\d{1,2}-\d{1,2}'
        ]
        
        for pattern in date_patterns:
            data['dates'].extend(re.findall(pattern, text))
        
        # Extract numbers
        number_pattern = r'\b\d+(?:,\d{3})*(?:\.\d+)?\b'
        data['numbers'] = re.findall(number_pattern, text)
        
        # Extract currencies
        currency_pattern = r'[R$€£¥]\s*\d+(?:,\d{3})*(?:\.\d+)?'
        data['currencies'] = re.findall(currency_pattern, text)
        
        # Extract percentages
        percentage_pattern = r'\d+(?:\.\d+)?%'
        data['percentages'] = re.findall(percentage_pattern, text)
        
        return data

class VectorizerAgent(BaseAgent):
    """Agent responsável por criar embeddings e armazenar no Qdrant"""
    
    def __init__(self, agent_id: str):
        super().__init__(agent_id, AgentType.VECTORIZER)
        self.embedding_model = None
        self.qdrant_client = None
        self._initialize_services()
    
    def _initialize_services(self):
        try:
            self.embedding_model = SentenceTransformer('sentence-transformers/all-MiniLM-L6-v2')
            self.qdrant_client = QdrantClient(host="localhost", port=6333)
            
            # Ensure collection exists
            collections = self.qdrant_client.get_collections()
            collection_names = [col.name for col in collections.collections]
            
            if "commodity_documents_enhanced" not in collection_names:
                self.qdrant_client.create_collection(
                    collection_name="commodity_documents_enhanced",
                    vectors_config=VectorParams(size=384, distance=Distance.COSINE),
                )
                logger.info("Created enhanced Qdrant collection")
        except Exception as e:
            logger.error(f"Error initializing VectorizerAgent services: {e}")
    
    async def process(self, task: ProcessingTask) -> AgentResult:
        start_time = time.time()
        self.is_active = True
        self.last_activity = datetime.now()
        
        try:
            text = task.metadata.get('extracted_text', '')
            content_analysis = task.metadata.get('content_analysis', {})
            quality_metrics = task.metadata.get('quality_metrics', {})
            
            if not text.strip():
                raise ValueError("No text to vectorize")
            
            # Create embedding
            embedding = self.embedding_model.encode(text).tolist()
            
            # Prepare enhanced metadata
            file_hash = hashlib.md5(text.encode()).hexdigest()
            
            point = PointStruct(
                id=file_hash,
                vector=embedding,
                payload={
                    'text': text,
                    'file_path': task.file_path,
                    'file_name': Path(task.file_path).name,
                    'processed_at': datetime.now().isoformat(),
                    'task_id': task.task_id,
                    'processing_strategy': task.strategy.value,
                    'quality_score': quality_metrics.get('quality_score', 0),
                    'entities': content_analysis.get('entities', []),
                    'keywords': content_analysis.get('keywords', []),
                    'document_type': content_analysis.get('document_type', 'unknown'),
                    'language': content_analysis.get('language', 'unknown'),
                    'structured_data': content_analysis.get('structured_data', {}),
                    'text_metrics': quality_metrics.get('text_metrics', {}),
                    'recommendations': quality_metrics.get('recommendations', [])
                }
            )
            
            # Store in Qdrant
            self.qdrant_client.upsert(
                collection_name="commodity_documents_enhanced",
                points=[point]
            )
            
            result = AgentResult(
                agent_id=self.agent_id,
                agent_type=self.agent_type,
                task_id=task.task_id,
                success=True,
                data={
                    'document_id': file_hash,
                    'embedding_dimension': len(embedding),
                    'stored_successfully': True
                },
                processing_time=time.time() - start_time,
                confidence=1.0
            )
            
        except Exception as e:
            logger.error(f"VectorizerAgent {self.agent_id} error: {e}")
            result = AgentResult(
                agent_id=self.agent_id,
                agent_type=self.agent_type,
                task_id=task.task_id,
                success=False,
                data={},
                processing_time=time.time() - start_time,
                error=str(e)
            )
        finally:
            self.is_active = False
            self.processed_count += 1
            
        return result

class CoordinatorAgent(BaseAgent):
    """Agent coordenador que gerencia o pipeline de processamento"""
    
    def __init__(self, agent_id: str):
        super().__init__(agent_id, AgentType.COORDINATOR)
        self.task_queue = Queue()
        self.agents = {
            'preprocessors': [],
            'ocr_specialists': [],
            'quality_assessors': [],
            'content_analyzers': [],
            'vectorizers': []
        }
        self._initialize_agent_pool()
        self.processing_stats = {
            'total_processed': 0,
            'successful': 0,
            'failed': 0,
            'average_processing_time': 0.0
        }
    
    def _initialize_agent_pool(self):
        """Initialize pool of specialized agents"""
        # Create multiple instances for parallel processing
        for i in range(2):
            self.agents['preprocessors'].append(PreprocessorAgent(f"preprocessor_{i}"))
            self.agents['ocr_specialists'].append(OCRSpecialistAgent(f"ocr_specialist_{i}"))
            self.agents['quality_assessors'].append(QualityAssessorAgent(f"quality_assessor_{i}"))
            self.agents['content_analyzers'].append(ContentAnalyzerAgent(f"content_analyzer_{i}"))
            self.agents['vectorizers'].append(VectorizerAgent(f"vectorizer_{i}"))
    
    async def process(self, task: ProcessingTask) -> AgentResult:
        start_time = time.time()
        self.is_active = True
        self.last_activity = datetime.now()
        
        try:
            logger.info(f"Coordinator processing task {task.task_id} with strategy {task.strategy.value}")
            
            if task.strategy == ProcessingStrategy.MULTI_AGENT:
                result = await self._multi_agent_pipeline(task)
            else:
                result = await self._single_strategy_process(task)
            
            # Update stats
            self.processing_stats['total_processed'] += 1
            if result.success:
                self.processing_stats['successful'] += 1
            else:
                self.processing_stats['failed'] += 1
            
            # Update average processing time
            current_time = result.processing_time
            total = self.processing_stats['total_processed']
            prev_avg = self.processing_stats['average_processing_time']
            self.processing_stats['average_processing_time'] = (prev_avg * (total - 1) + current_time) / total
            
        except Exception as e:
            logger.error(f"Coordinator error: {e}")
            result = AgentResult(
                agent_id=self.agent_id,
                agent_type=self.agent_type,
                task_id=task.task_id,
                success=False,
                data={},
                processing_time=time.time() - start_time,
                error=str(e)
            )
        finally:
            self.is_active = False
            self.processed_count += 1
        
        return result
    
    async def _multi_agent_pipeline(self, task: ProcessingTask) -> AgentResult:
        """Execute full multi-agent pipeline"""
        pipeline_start = time.time()
        pipeline_results = {'stages': []}
        
        try:
            # Stage 1: Preprocessing
            preprocessor = self._get_available_agent('preprocessors')
            prep_result = await preprocessor.process(task)
            pipeline_results['stages'].append({'stage': 'preprocessing', 'result': asdict(prep_result)})
            
            if not prep_result.success:
                raise ValueError(f"Preprocessing failed: {prep_result.error}")
            
            # Update task metadata with preprocessing results
            task.metadata.update(prep_result.data)
            
            # Stage 2: OCR Processing
            ocr_specialist = self._get_available_agent('ocr_specialists')
            ocr_result = await ocr_specialist.process(task)
            pipeline_results['stages'].append({'stage': 'ocr', 'result': asdict(ocr_result)})
            
            if not ocr_result.success:
                raise ValueError(f"OCR processing failed: {ocr_result.error}")
            
            # Extract best text
            best_result = ocr_result.data.get('best_result', {})
            extracted_text = best_result.get('text', '')
            task.metadata['extracted_text'] = extracted_text
            task.metadata['ocr_results'] = ocr_result.data
            
            # Stage 3: Quality Assessment
            quality_assessor = self._get_available_agent('quality_assessors')
            quality_result = await quality_assessor.process(task)
            pipeline_results['stages'].append({'stage': 'quality_assessment', 'result': asdict(quality_result)})
            
            if quality_result.success:
                task.metadata['quality_metrics'] = quality_result.data
            
            # Stage 4: Content Analysis
            content_analyzer = self._get_available_agent('content_analyzers')
            content_result = await content_analyzer.process(task)
            pipeline_results['stages'].append({'stage': 'content_analysis', 'result': asdict(content_result)})
            
            if content_result.success:
                task.metadata['content_analysis'] = content_result.data
            
            # Stage 5: Vectorization
            vectorizer = self._get_available_agent('vectorizers')
            vector_result = await vectorizer.process(task)
            pipeline_results['stages'].append({'stage': 'vectorization', 'result': asdict(vector_result)})
            
            # Compile final result
            total_processing_time = time.time() - pipeline_start
            overall_success = all(stage['result']['success'] for stage in pipeline_results['stages'])
            
            final_result = AgentResult(
                agent_id=self.agent_id,
                agent_type=self.agent_type,
                task_id=task.task_id,
                success=overall_success,
                data={
                    'pipeline_results': pipeline_results,
                    'final_text': extracted_text,
                    'quality_score': quality_result.data.get('quality_score', 0) if quality_result.success else 0,
                    'document_analysis': content_result.data if content_result.success else {},
                    'vector_stored': vector_result.success,
                    'processing_summary': {
                        'stages_completed': len(pipeline_results['stages']),
                        'total_processing_time': total_processing_time,
                        'text_length': len(extracted_text),
                        'preprocessing_variants': len(prep_result.data.get('processed_images', [])),
                        'ocr_variants_tested': ocr_result.data.get('variants_processed', 0)
                    }
                },
                processing_time=total_processing_time,
                confidence=quality_result.data.get('quality_score', 0) if quality_result.success else 0
            )
            
        except Exception as e:
            logger.error(f"Multi-agent pipeline error: {e}")
            final_result = AgentResult(
                agent_id=self.agent_id,
                agent_type=self.agent_type,
                task_id=task.task_id,
                success=False,
                data={'pipeline_results': pipeline_results},
                processing_time=time.time() - pipeline_start,
                error=str(e)
            )
        
        return final_result
    
    async def _single_strategy_process(self, task: ProcessingTask) -> AgentResult:
        """Process with single strategy (fast/balanced/accurate)"""
        start_time = time.time()
        
        try:
            # For now, use simplified OCR processing
            ocr_specialist = self._get_available_agent('ocr_specialists')
            
            # Adjust processing based on strategy
            if task.strategy == ProcessingStrategy.FAST:
                # Skip preprocessing, use single OCR engine
                task.metadata['processed_images'] = [task.file_path]
            elif task.strategy == ProcessingStrategy.BALANCED:
                # Basic preprocessing
                preprocessor = self._get_available_agent('preprocessors')
                prep_result = await preprocessor.process(task)
                if prep_result.success:
                    task.metadata.update(prep_result.data)
            elif task.strategy == ProcessingStrategy.ACCURATE:
                # Full preprocessing + quality assessment
                preprocessor = self._get_available_agent('preprocessors')
                prep_result = await preprocessor.process(task)
                if prep_result.success:
                    task.metadata.update(prep_result.data)
            
            # OCR Processing
            ocr_result = await ocr_specialist.process(task)
            
            if not ocr_result.success:
                raise ValueError(f"OCR failed: {ocr_result.error}")
            
            best_result = ocr_result.data.get('best_result', {})
            extracted_text = best_result.get('text', '')
            
            result = AgentResult(
                agent_id=self.agent_id,
                agent_type=self.agent_type,
                task_id=task.task_id,
                success=True,
                data={
                    'extracted_text': extracted_text,
                    'ocr_confidence': best_result.get('confidence', 0),
                    'processing_strategy': task.strategy.value,
                    'ocr_method': best_result.get('engine', 'unknown')
                },
                processing_time=time.time() - start_time,
                confidence=best_result.get('confidence', 0)
            )
            
        except Exception as e:
            logger.error(f"Single strategy processing error: {e}")
            result = AgentResult(
                agent_id=self.agent_id,
                agent_type=self.agent_type,
                task_id=task.task_id,
                success=False,
                data={},
                processing_time=time.time() - start_time,
                error=str(e)
            )
        
        return result
    
    def _get_available_agent(self, agent_type: str) -> BaseAgent:
        """Get available agent from pool"""
        agents = self.agents.get(agent_type, [])
        if not agents:
            raise ValueError(f"No agents available for type: {agent_type}")
        
        # Return first non-active agent or first agent if all are active
        for agent in agents:
            if not agent.is_active:
                return agent
        
        return agents[0]  # Return first agent if all are busy
    
    def get_system_status(self) -> Dict[str, Any]:
        """Get comprehensive system status"""
        agent_status = {}
        
        for agent_type, agents in self.agents.items():
            agent_status[agent_type] = [agent.get_status() for agent in agents]
        
        return {
            'coordinator_status': self.get_status(),
            'processing_stats': self.processing_stats,
            'agent_pools': agent_status,
            'queue_size': self.task_queue.qsize(),
            'system_timestamp': datetime.now().isoformat()
        }

# FastAPI App and Enhanced Endpoints
app = FastAPI(title="OCR Enhanced Multi-Agent Service", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global coordinator instance
coordinator = None
smart_analyst = None

# Pydantic models for API
class EnhancedOCRRequest(BaseModel):
    file_path: str
    strategy: ProcessingStrategy = ProcessingStrategy.BALANCED
    priority: int = 1
    force_reprocess: bool = False

class EnhancedOCRResult(BaseModel):
    task_id: str
    success: bool
    extracted_text: str
    confidence: float
    processing_time: float
    strategy_used: str
    quality_metrics: Optional[Dict[str, Any]] = None
    content_analysis: Optional[Dict[str, Any]] = None
    recommendations: Optional[List[str]] = None
    error: Optional[str] = None

class AnalysisRequest(BaseModel):
    query: str
    intent: str = "auto"  # auto, local, openai
    limit: int = 10
    min_score: float = 0.7
    context_limit: int = 5

class AnalysisResult(BaseModel):
    query: str
    success: bool
    strategy_used: str
    response_type: str
    processing_time: float
    confidence: float
    # Campos para busca local
    documents_found: Optional[int] = None
    documents: Optional[List[Dict[str, Any]]] = None
    summary: Optional[str] = None
    # Campos para análise OpenAI
    analysis: Optional[str] = None
    context_documents: Optional[int] = None
    model_used: Optional[str] = None
    tokens_used: Optional[int] = None
    error: Optional[str] = None

@app.on_event("startup")
async def startup_event():
    """Initialize the multi-agent system"""
    global coordinator, smart_analyst
    coordinator = CoordinatorAgent("main_coordinator")
    
    # Import e inicializar SmartAnalysisAgent
    try:
        from smart_analysis_agent import SmartAnalysisAgent
        smart_analyst = SmartAnalysisAgent("smart_analyst_main")
        logger.info("SmartAnalysisAgent initialized successfully")
    except Exception as e:
        logger.error(f"Error initializing SmartAnalysisAgent: {e}")
        smart_analyst = None
    
    logger.info("Enhanced OCR Multi-Agent Service started")

@app.get("/")
async def root():
    return {
        "service": "Enhanced OCR Multi-Agent Service",
        "version": "2.0.0",
        "status": "running",
        "timestamp": datetime.now().isoformat(),
        "agents": {
            "coordinator": 1,
            "preprocessors": 2,
            "ocr_specialists": 2,
            "quality_assessors": 2,
            "content_analyzers": 2,
            "vectorizers": 2
        }
    }

@app.get("/system/status")
async def get_system_status():
    """Get comprehensive system status"""
    if coordinator:
        return coordinator.get_system_status()
    else:
        return {"error": "Coordinator not initialized"}

@app.post("/ocr/enhanced", response_model=EnhancedOCRResult)
async def enhanced_ocr_process(request: EnhancedOCRRequest):
    """Enhanced OCR processing with multi-agent system"""
    try:
        if not coordinator:
            raise HTTPException(status_code=500, detail="Coordinator not initialized")
        
        # Validate file exists
        if not os.path.exists(request.file_path):
            raise HTTPException(status_code=404, detail=f"File not found: {request.file_path}")
        
        # Create processing task
        task_id = f"task_{int(time.time() * 1000)}_{hash(request.file_path) % 10000}"
        task = ProcessingTask(
            task_id=task_id,
            file_path=request.file_path,
            strategy=request.strategy,
            priority=request.priority,
            metadata={'force_reprocess': request.force_reprocess}
        )
        
        # Process task
        result = await coordinator.process(task)
        
        # Format response
        if result.success:
            pipeline_data = result.data.get('pipeline_results', {})
            final_text = result.data.get('final_text', result.data.get('extracted_text', ''))
            
            return EnhancedOCRResult(
                task_id=task_id,
                success=True,
                extracted_text=final_text,
                confidence=result.confidence,
                processing_time=result.processing_time,
                strategy_used=request.strategy.value,
                quality_metrics={'quality_score': result.data.get('quality_score', 0)} if result.data.get('quality_score') is not None else None,
                content_analysis=result.data.get('document_analysis'),
                recommendations=result.data.get('processing_summary', {}).get('recommendations', [])
            )
        else:
            return EnhancedOCRResult(
                task_id=task_id,
                success=False,
                extracted_text="",
                confidence=0.0,
                processing_time=result.processing_time,
                strategy_used=request.strategy.value,
                error=result.error
            )
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Enhanced OCR processing error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/ocr/search/enhanced")
async def enhanced_search(query: str, limit: int = 10, min_score: float = 0.7):
    """Enhanced search with content analysis"""
    try:
        # Use vectorizer agent's Qdrant client for search
        vectorizer = coordinator.agents['vectorizers'][0] if coordinator else None
        if not vectorizer or not vectorizer.qdrant_client:
            raise HTTPException(status_code=500, detail="Vector search not available")
        
        # Create query embedding
        query_embedding = vectorizer.embedding_model.encode(query).tolist()
        
        # Search in enhanced collection
        search_result = vectorizer.qdrant_client.search(
            collection_name="commodity_documents_enhanced",
            query_vector=query_embedding,
            limit=limit,
            score_threshold=min_score
        )
        
        results = []
        for hit in search_result:
            payload = hit.payload
            results.append({
                "score": hit.score,
                "text_preview": payload.get("text", "")[:300] + "...",
                "file_name": payload.get("file_name", ""),
                "document_type": payload.get("document_type", "unknown"),
                "language": payload.get("language", "unknown"),
                "quality_score": payload.get("quality_score", 0),
                "keywords": payload.get("keywords", [])[:5],
                "entities": payload.get("entities", [])[:3],
                "processed_at": payload.get("processed_at", ""),
                "processing_strategy": payload.get("processing_strategy", "unknown")
            })
        
        return {
            "query": query,
            "results": results,
            "total_found": len(results),
            "search_timestamp": datetime.now().isoformat()
        }
    
    except Exception as e:
        logger.error(f"Enhanced search error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/analyze", response_model=AnalysisResult)
async def smart_analysis(request: AnalysisRequest):
    """Endpoint unificado para análise inteligente - decide automaticamente entre local/OpenAI"""
    try:
        if not smart_analyst:
            raise HTTPException(status_code=500, detail="SmartAnalysisAgent not available")
        
        # Criar task para o SmartAnalysisAgent
        task_id = f"analysis_{int(time.time() * 1000)}"
        task = ProcessingTask(
            task_id=task_id,
            file_path="",  # Não usado para análise
            strategy=ProcessingStrategy.BALANCED,
            metadata={
                'query': request.query,
                'intent': request.intent,
                'limit': request.limit,
                'min_score': request.min_score,
                'context_limit': request.context_limit
            }
        )
        
        # Processar com SmartAnalysisAgent
        result = await smart_analyst.process(task)
        
        if result.success:
            # Formatar resposta baseado no tipo
            response_data = result.data
            
            return AnalysisResult(
                query=request.query,
                success=True,
                strategy_used=response_data.get('strategy_used', 'unknown'),
                response_type=response_data.get('response_type', 'unknown'),
                processing_time=result.processing_time,
                confidence=result.confidence,
                # Campos condicionais baseados no tipo de resposta
                documents_found=response_data.get('documents_found'),
                documents=response_data.get('documents'),
                summary=response_data.get('summary'),
                analysis=response_data.get('analysis'),
                context_documents=response_data.get('context_documents'),
                model_used=response_data.get('model_used'),
                tokens_used=response_data.get('tokens_used')
            )
        else:
            return AnalysisResult(
                query=request.query,
                success=False,
                strategy_used=result.data.get('strategy_used', 'error'),
                response_type='error',
                processing_time=result.processing_time,
                confidence=0.0,
                error=result.error
            )
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Smart analysis error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/analyze/test")
async def test_smart_analysis():
    """Endpoint para testar o sistema de análise inteligente"""
    test_queries = [
        {
            "query": "busque documentos sobre milho",
            "expected_strategy": "local"
        },
        {
            "query": "analise as tendências de preço do milho e faça recomendações",
            "expected_strategy": "openai"
        },
        {
            "query": "mostre os últimos relatórios",
            "expected_strategy": "local"
        },
        {
            "query": "qual o impacto da seca nos preços das commodities?",
            "expected_strategy": "openai"
        }
    ]
    
    results = []
    for test_case in test_queries:
        if smart_analyst:
            strategy = smart_analyst._classify_intent(test_case["query"])
            results.append({
                "query": test_case["query"],
                "expected": test_case["expected_strategy"],
                "predicted": strategy,
                "correct": strategy == test_case["expected_strategy"]
            })
    
    accuracy = sum(1 for r in results if r["correct"]) / len(results) if results else 0
    
    return {
        "smart_analyst_available": smart_analyst is not None,
        "test_results": results,
        "accuracy": accuracy,
        "status": "SmartAnalysisAgent working correctly" if accuracy > 0.7 else "Classification needs improvement"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8003)
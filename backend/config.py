"""
SpotLight バックエンド設定
開発・本番環境の設定を管理
"""
import os
from datetime import timedelta

class Config:
    """基本設定クラス"""
    # データベース設定
    DB_HOST = os.getenv('DB_HOST', 'localhost')
    DB_PORT = os.getenv('DB_PORT', '5432')
    DB_NAME = os.getenv('DB_NAME', 'spotlight')
    DB_USER = os.getenv('DB_USER', 'toudai')
    DB_PASSWORD = os.getenv('DB_PASSWORD', 'kcsf2026')
    
    # Flask設定
    SECRET_KEY = os.getenv('SECRET_KEY', 'dev-secret-key-change-in-production')
    DEBUG = False
    TESTING = False
    
    # CORS設定
    CORS_ORIGINS = ['http://localhost:3000', 'http://127.0.0.1:3000']
    
    # サーバー設定
    HOST = os.getenv('HOST', '0.0.0.0')
    PORT = int(os.getenv('PORT', 5000))
    
    # セッション設定
    PERMANENT_SESSION_LIFETIME = timedelta(hours=24)
    
    # ファイルアップロード設定
    MAX_CONTENT_LENGTH = 16 * 1024 * 1024  # 16MB
    UPLOAD_FOLDER = os.getenv('UPLOAD_FOLDER', 'uploads')
    
    # API設定
    API_RATE_LIMIT = '1000 per hour'
    API_RATE_LIMIT_PER_METHOD = '200 per hour'

class DevelopmentConfig(Config):
    """開発環境設定"""
    DEBUG = True
    CORS_ORIGINS = ['http://localhost:5000', 'http://127.0.0.1:5000', 'http://localhost:8080']

class ProductionConfig(Config):
    """本番環境設定"""
    DEBUG = False
    CORS_ORIGINS = os.getenv('CORS_ORIGINS', '').split(',')
    
    # 本番環境では必ず環境変数から設定を取得
    SECRET_KEY = os.getenv('SECRET_KEY')
    if not SECRET_KEY:
        raise ValueError("SECRET_KEY environment variable must be set in production")

class TestingConfig(Config):
    """テスト環境設定"""
    TESTING = True
    DEBUG = True
    DB_NAME = os.getenv('TEST_DB_NAME', 'spotlight_test')

# 設定辞書
config = {
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'testing': TestingConfig,
    'default': DevelopmentConfig
}

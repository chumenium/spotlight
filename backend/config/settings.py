"""
アプリケーション設定ファイル
環境変数から設定を読み込みます
"""
import os
from dotenv import load_dotenv

# 環境変数の読み込み
load_dotenv()

class Config:
    """基本設定"""
    # Flask設定
    SECRET_KEY = os.getenv('SECRET_KEY', 'your-secret-key-change-in-production')
    DEBUG = os.getenv('DEBUG', 'False') == 'True'
    
    # CORS設定
    CORS_ORIGINS = os.getenv('CORS_ORIGINS', '*').split(',')
    
    # JWT設定
    JWT_SECRET = os.getenv('JWT_SECRET', 'your-jwt-secret-change-in-production')
    JWT_ALGORITHM = 'HS256'
    JWT_EXP_HOURS = int(os.getenv('JWT_EXP_HOURS', '24'))
    
    # Google認証設定
    GOOGLE_CLIENT_ID = os.getenv('GOOGLE_CLIENT_ID', '')
    
    # データベース設定（DB担当メンバーが設定）
    DB_HOST = os.getenv('DB_HOST', 'localhost')
    DB_NAME = os.getenv('DB_NAME', 'spotlight')
    DB_USER = os.getenv('DB_USER', 'postgres')
    DB_PASSWORD = os.getenv('DB_PASSWORD', 'password')
    DB_PORT = os.getenv('DB_PORT', '5432')
    
    # サーバー設定
    HOST = os.getenv('HOST', '0.0.0.0')
    PORT = int(os.getenv('PORT', '5000'))

class DevelopmentConfig(Config):
    """開発環境設定"""
    DEBUG = True

class ProductionConfig(Config):
    """本番環境設定"""
    DEBUG = False

# 環境に応じた設定を選択
config = {
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'default': DevelopmentConfig
}


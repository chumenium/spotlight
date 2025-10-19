"""
認証関連のユーティリティ
JWT認証とGoogle認証の処理
"""
import jwt
import datetime
from functools import wraps
from flask import request, jsonify
from config.settings import Config

def generate_jwt_token(payload_data):
    """
    JWTトークンを生成
    
    Args:
        payload_data (dict): トークンに含めるデータ
    
    Returns:
        str: JWTトークン
    """
    payload = {
        **payload_data,
        'exp': datetime.datetime.utcnow() + datetime.timedelta(hours=Config.JWT_EXP_HOURS)
    }
    token = jwt.encode(payload, Config.JWT_SECRET, algorithm=Config.JWT_ALGORITHM)
    return token

def decode_jwt_token(token):
    """
    JWTトークンをデコード
    
    Args:
        token (str): JWTトークン
    
    Returns:
        dict: デコードされたペイロード
    
    Raises:
        jwt.ExpiredSignatureError: トークンの有効期限切れ
        jwt.InvalidTokenError: 無効なトークン
    """
    return jwt.decode(token, Config.JWT_SECRET, algorithms=[Config.JWT_ALGORITHM])

def jwt_required(f):
    """
    JWT認証が必要なエンドポイントに適用するデコレーター
    
    Usage:
        @app.route('/api/protected')
        @jwt_required
        def protected_route():
            user = request.user
            return jsonify({'message': 'Protected data'})
    """
    @wraps(f)
    def decorated_function(*args, **kwargs):
        auth_header = request.headers.get('Authorization', '')
        
        if not auth_header.startswith('Bearer '):
            return jsonify({
                'success': False,
                'error': {
                    'code': 'AUTHENTICATION_ERROR',
                    'message': 'Authorization header missing or invalid'
                }
            }), 401
        
        token = auth_header.split(' ')[1]
        
        try:
            payload = decode_jwt_token(token)
            request.user = payload
            return f(*args, **kwargs)
        except jwt.ExpiredSignatureError:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'AUTHENTICATION_ERROR',
                    'message': 'Token has expired'
                }
            }), 401
        except jwt.InvalidTokenError:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'AUTHENTICATION_ERROR',
                    'message': 'Invalid token'
                }
            }), 401
    
    return decorated_function

def verify_google_token(id_token):
    """
    GoogleのID tokenを検証
    
    Args:
        id_token (str): GoogleのIDトークン
    
    Returns:
        dict: ユーザー情報
    
    Note:
        実装はGoogle認証ライブラリを使用します
        DB担当メンバーと連携してユーザー情報をデータベースに保存
    """
    # TODO: Google認証の実装
    # from google.oauth2 import id_token
    # from google.auth.transport import requests
    # idinfo = id_token.verify_oauth2_token(token, requests.Request(), Config.GOOGLE_CLIENT_ID)
    
    # 現時点ではモック実装
    return {
        'google_id': 'mock_google_id',
        'email': 'mock@example.com',
        'name': 'Mock User',
        'picture': 'https://example.com/avatar.jpg'
    }


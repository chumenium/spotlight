"""
認証関連のエンドポイント
ユーザー登録、ログイン、Firebase認証など
"""
from flask import Blueprint, request, jsonify
from backend.models.create_username import create_username
from utils.auth import generate_jwt_token, verify_google_token
import firebase_admin
from firebase_admin import credentials, auth as firebase_auth
import jwt
import datetime
import psycopg2
from functools import wraps
import os

# ====== 設定 ======
from config import config

# 現在の環境設定を取得
current_config = config['default']
JWT_SECRET = current_config.JWT_SECRET
JWT_ALGORITHM = current_config.JWT_ALGORITHM
JWT_EXP_HOURS = current_config.JWT_EXP_HOURS
GOOGLE_CLIENT_ID = current_config.GOOGLE_CLIENT_ID

# ====== Firebase Admin SDK初期化 ======
def initialize_firebase():
    """Firebase Admin SDKを初期化"""
    try:
        # Firebase Admin SDKが既に初期化されているかチェック
        if firebase_admin._apps:
            print("✅ Firebase Admin SDK already initialized")
            return True
        
        # Firebase Admin SDKの設定ファイルパス
        firebase_config_path = os.path.join(os.path.dirname(__file__), '..', 'spotlight-597c4-firebase-adminsdk-fbsvc-8820bfe6ef.json')
        
        if os.path.exists(firebase_config_path):
            # 設定ファイルから初期化
            cred = credentials.Certificate(firebase_config_path)
            firebase_admin.initialize_app(cred)
            print("✅ Firebase Admin SDK initialized with config file")
            return True
        else:
            # 環境変数から初期化（本番環境用）
            firebase_admin.initialize_app()
            print("✅ Firebase Admin SDK initialized with environment variables")
            return True
            
    except Exception as e:
        print(f"❌ Firebase Admin SDK initialization failed: {e}")
        return False

# Firebase Admin SDKを初期化
firebase_initialized = initialize_firebase()
# ====== JWT認証デコレーター ======
def jwt_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        auth_header = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            return jsonify({"error": "Missing or invalid Authorization header"}), 401
        token = auth_header.split(" ")[1]
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        except jwt.ExpiredSignatureError:
            return jsonify({"error": "Token has expired"}), 401
        except jwt.InvalidTokenError:
            return jsonify({"error": "Invalid token"}), 401
        request.user = payload
        return f(*args, **kwargs)
    return decorated_function

auth_bp = Blueprint('auth', __name__, url_prefix='/api/auth')



# ====== Firebase認証 → DB登録 → JWT発行 ======
@auth_bp.route("/firebase", methods=["POST"])
def firebase_auth():
    """
    Firebase認証エンドポイント
    
    Firebase IDトークンを受け取ってJWTトークンを発行します
    
    Request Body:
        {
            "id_token": "firebase_id_token_here",
            "token": "fcm_notification_token" (optional)
        }
    
    Returns:
        JSON: JWTトークンとユーザー情報
    """
    try:
        data = request.get_json()
        id_token_str = data.get("id_token")
        fcm_token = data.get("token")  # FCM通知トークン（オプション）

        if not id_token_str:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'VALIDATION_ERROR',
                    'message': 'id_token is required'
                }
            }), 400

        # Firebase Admin SDKでIDトークンを検証
        if not firebase_initialized:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'SERVER_ERROR',
                    'message': 'Firebase Admin SDK not initialized'
                }
            }), 500
        
        try:
            # Firebase Admin SDKでIDトークンを検証
            decoded_token = firebase_auth.verify_id_token(id_token_str)
            firebase_uid = decoded_token['uid']
            
            # ユーザー情報を取得
            email = decoded_token.get('email', '')
            name = decoded_token.get('name', '')
            picture = decoded_token.get('picture', '')
            
        except firebase_auth.InvalidIdTokenError:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'AUTHENTICATION_ERROR',
                    'message': 'Invalid Firebase ID token'
                }
            }), 400

        # データベースにユーザー情報を保存（FCMトークンも含む）
        create_username(firebase_uid, fcm_token)

        # JWTトークンを生成
        jwt_payload = {
            "firebase_uid": firebase_uid,
            "email": email,
            "name": name,
            "picture": picture,
            "exp": datetime.datetime.utcnow() + datetime.timedelta(hours=JWT_EXP_HOURS)
        }
        
        jwt_token = jwt.encode(jwt_payload, JWT_SECRET, algorithm=JWT_ALGORITHM)

        return jsonify({
            'success': True,
            'data': {
                'jwt': jwt_token,
                'user': {
                    'firebase_uid': firebase_uid,
                    'email': email,
                    'name': name,
                    'picture': picture
                }
            }
        }), 200

    except ValueError as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'AUTHENTICATION_ERROR',
                'message': 'Invalid Firebase ID token'
            }
        }), 400
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': str(e)
            }
        }), 500


# ====== 通知トークン更新 ======
@auth_bp.route("/api/update_token", methods=["POST"])
@jwt_required
def update_token():
    data = request.get_json()
    new_token = data.get("token")
    if not new_token:
        return jsonify({"error": "token is required"}), 400

    uid = request.user["firebase_uid"]

    # conn = get_db_connection()
    # cur = conn.cursor()
    # cur.execute("UPDATE \"user\" SET token = %s WHERE userID = %s", (new_token, uid))
    # conn.commit()
    # cur.close()
    # conn.close()

    return jsonify({"status": "updated"})



@auth_bp.route('/register', methods=['POST'])
def register():
    """
    ユーザー登録
    
    Request Body:
        {
            "nickname": "ユーザー名",
            "email": "user@example.com",
            "password": "password123"
        }
    
    Returns:
        JSON: ユーザー情報とJWTトークン
    """
    try:
        data = request.get_json()
        nickname = data.get('nickname')
        email = data.get('email')
        password = data.get('password')
        
        # バリデーション
        if not all([nickname, email, password]):
            return jsonify({
                'success': False,
                'error': {
                    'code': 'VALIDATION_ERROR',
                    'message': 'All fields are required'
                }
            }), 400
        
        # TODO: DB担当メンバーがユーザー登録処理を実装
        # - パスワードのハッシュ化
        # - ユーザーの重複チェック
        # - データベースへの保存
        
        # モックレスポンス
        user_data = {
            'id': 'user_mock_123',
            'nickname': nickname,
            'email': email,
            'profileImageUrl': None,
            'createdAt': '2024-01-01T00:00:00Z'
        }
        
        # JWTトークン生成
        token = generate_jwt_token({
            'user_id': user_data['id'],
            'email': email,
            'nickname': nickname
        })
        
        return jsonify({
            'success': True,
            'data': {
                'user': user_data,
                'token': token
            }
        }), 201
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': str(e)
            }
        }), 500

@auth_bp.route('/login', methods=['POST'])
def login():
    """
    ログイン
    
    Request Body:
        {
            "email": "user@example.com",
            "password": "password123"
        }
    
    Returns:
        JSON: ユーザー情報とJWTトークン
    """
    try:
        data = request.get_json()
        email = data.get('email')
        password = data.get('password')
        
        # バリデーション
        if not all([email, password]):
            return jsonify({
                'success': False,
                'error': {
                    'code': 'VALIDATION_ERROR',
                    'message': 'Email and password are required'
                }
            }), 400
        
        # TODO: DB担当メンバーがログイン処理を実装
        # - ユーザーの存在確認
        # - パスワードの検証
        # - ユーザー情報の取得
        
        # モックレスポンス
        user_data = {
            'id': 'user_mock_123',
            'nickname': 'テストユーザー',
            'email': email,
            'profileImageUrl': 'https://example.com/avatar.jpg',
            'followersCount': 100,
            'followingCount': 50,
            'postsCount': 25
        }
        
        # JWTトークン生成
        token = generate_jwt_token({
            'user_id': user_data['id'],
            'email': email,
            'nickname': user_data['nickname']
        })
        
        return jsonify({
            'success': True,
            'data': {
                'user': user_data,
                'token': token
            }
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': str(e)
            }
        }), 500

@auth_bp.route('/google', methods=['POST'])
def google_auth():
    """
    Google認証
    
    Request Body:
        {
            "id_token": "google_id_token_here"
        }
    
    Returns:
        JSON: ユーザー情報とJWTトークン
    """
    try:
        data = request.get_json()
        id_token = data.get('id_token')
        
        if not id_token:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'VALIDATION_ERROR',
                    'message': 'id_token is required'
                }
            }), 400
        
        # Googleトークンの検証
        google_user = verify_google_token(id_token)
        
        # TODO: DB担当メンバーがGoogle認証処理を実装
        # - Googleアカウント情報でユーザー検索
        # - 存在しない場合は新規作成
        # - ユーザー情報の取得
        
        # JWTトークン生成
        token = generate_jwt_token({
            'google_id': google_user['google_id'],
            'email': google_user['email'],
            'name': google_user['name']
        })
        
        return jsonify({
            'success': True,
            'data': {
                'user': {
                    'email': google_user['email'],
                    'name': google_user['name'],
                    'picture': google_user['picture']
                },
                'token': token
            }
        }), 200
        
    except ValueError:
        return jsonify({
            'success': False,
            'error': {
                'code': 'AUTHENTICATION_ERROR',
                'message': 'Invalid Google token'
            }
        }), 400
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': str(e)
            }
        }), 500


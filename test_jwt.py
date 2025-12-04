#!/usr/bin/env python3
"""
JWTトークン取得テストスクリプト
Firebase IDトークンをバックエンドに送信してJWTトークンを取得するテスト
"""
import requests
import json
import time

# テスト用のFirebase IDトークン（モック）
MOCK_FIREBASE_ID_TOKEN = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJodHRwczovL3NlY3VyZXRva2VuLmdvb2dsZS5jb20vZmlyZWJhc2UtYWRtaW5zZGstZ2V0eGgiLCJhdWQiOiJmaXJlYmFzZS1hZG1pbnNkay1nZXR4aCIsImF1dGhfdGltZSI6MTcwMDAwMDAwMCwidXNlcl9pZCI6InRlc3R1c2VyMTIzIiwic3ViIjoidGVzdHVzZXIxMjMiLCJpYXQiOjE3MDAwMDAwMDAsImV4cCI6MTcwMDA4NjQwMCwiZW1haWwiOiJ0ZXN0QGV4YW1wbGUuY29tIiwicGhvbmVfbnVtYmVyIjoiKzgxLTkwLTEyMzQtNTY3OCIsImVtYWlsX3ZlcmlmaWVkIjpmYWxzZSwiZmlyZWJhc2UiOnsiaWRlbnRpdGllcyI6eyJlbWFpbCI6WyJ0ZXN0QGV4YW1wbGUuY29tIl0sInBob25lIjpbIis4MS05MC0xMjM0LTU2NzgiXX0sInNpZ25faW5fcHJvdmlkZXIiOiJwYXNzd29yZCJ9fQ.mock_signature"

def test_jwt_token_retrieval():
    """JWTトークン取得テスト"""
    print("🔐 JWTトークン取得テスト開始")
    print("=" * 50)
    
    # バックエンドサーバーのURL
    backend_url = "http://localhost:5000/api/auth/firebase"
    
    # リクエストデータ
    request_data = {
        "id_token": MOCK_FIREBASE_ID_TOKEN,
        "token": "test_fcm_token_123"  # FCM通知トークン（テスト用）
    }
    
    try:
        print(f"📤 リクエスト送信先: {backend_url}")
        print(f"📤 送信データ: {json.dumps(request_data, indent=2, ensure_ascii=False)}")
        print()
        
        # HTTPリクエスト送信
        response = requests.post(
            backend_url,
            headers={'Content-Type': 'application/json'},
            json=request_data,
            timeout=10
        )
        
        print(f"📥 レスポンスステータス: {response.status_code}")
        print(f"📥 レスポンスヘッダー: {dict(response.headers)}")
        print()
        
        if response.status_code == 200:
            response_data = response.json()
            print("✅ JWTトークン取得成功!")
            print(f"📋 レスポンスデータ:")
            print(json.dumps(response_data, indent=2, ensure_ascii=False))
            
            # JWTトークンの詳細表示
            if 'data' in response_data and 'jwt' in response_data['data']:
                jwt_token = response_data['data']['jwt']
                print(f"\n🔑 JWTトークン: {jwt_token}")
                
                # JWTトークンの構造を解析（デバッグ用）
                try:
                    import jwt as pyjwt
                    decoded = pyjwt.decode(jwt_token, options={"verify_signature": False})
                    print(f"🔍 JWTトークン内容:")
                    print(json.dumps(decoded, indent=2, ensure_ascii=False))
                except Exception as e:
                    print(f"⚠️ JWTトークン解析エラー: {e}")
            
        else:
            print(f"❌ エラー: {response.status_code}")
            print(f"📋 エラーレスポンス: {response.text}")
            
    except requests.exceptions.ConnectionError:
        print("❌ 接続エラー: バックエンドサーバーが起動していません")
        print("💡 解決方法: 'cd backend && python app.py' でサーバーを起動してください")
    except requests.exceptions.Timeout:
        print("❌ タイムアウトエラー: サーバーの応答が遅すぎます")
    except Exception as e:
        print(f"❌ 予期しないエラー: {e}")
    
    print("=" * 50)
    print("🔐 JWTトークン取得テスト終了")

def test_server_status():
    """サーバー状態確認"""
    print("🔍 サーバー状態確認")
    print("=" * 30)
    
    try:
        response = requests.get("http://localhost:5000", timeout=5)
        print(f"✅ サーバー起動中: {response.status_code}")
    except requests.exceptions.ConnectionError:
        print("❌ サーバーが起動していません")
        print("💡 バックエンドサーバーを起動してください: cd backend && python app.py")
    except Exception as e:
        print(f"❌ サーバー確認エラー: {e}")
    
    print("=" * 30)

if __name__ == "__main__":
    print("🚀 SpotLight JWTトークンテスト")
    print()
    
    # サーバー状態確認
    test_server_status()
    print()
    
    # JWTトークン取得テスト
    test_jwt_token_retrieval()

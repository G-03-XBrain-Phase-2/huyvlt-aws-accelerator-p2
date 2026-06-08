import os
import requests
import pymysql
import boto3
from flask import Flask, render_template, request, redirect, url_for
from botocore.exceptions import ClientError

app = Flask(__name__)

# DB Configurations read from environment variables
DB_HOST = os.environ.get("DB_HOST", "")
DB_NAME = os.environ.get("DB_NAME", "appdb")
DB_USER = os.environ.get("DB_USER", "admin")
DB_PASS = os.environ.get("DB_PASS", "")
S3_BUCKET = os.environ.get("S3_BUCKET", "")
AWS_REGION = os.environ.get("AWS_REGION", "ap-southeast-1")

def get_ec2_metadata():
    metadata = {
        "instance_id": "N/A",
        "instance_type": "N/A",
        "az": "N/A",
        "private_ip": "N/A"
    }
    try:
        # Fetch IMDSv2 token
        token_url = "http://169.254.169.254/latest/api/token"
        headers = {"X-aws-ec2-metadata-token-ttl-seconds": "60"}
        token_resp = requests.put(token_url, headers=headers, timeout=2)
        
        if token_resp.status_code == 200:
            token = token_resp.text
            meta_headers = {"X-aws-ec2-metadata-token": token}
            
            # Fetch instance info
            metadata["instance_id"] = requests.get("http://169.254.169.254/latest/meta-data/instance-id", headers=meta_headers, timeout=2).text
            metadata["instance_type"] = requests.get("http://169.254.169.254/latest/meta-data/instance-type", headers=meta_headers, timeout=2).text
            metadata["az"] = requests.get("http://169.254.169.254/latest/meta-data/placement/availability-zone", headers=meta_headers, timeout=2).text
            metadata["private_ip"] = requests.get("http://169.254.169.254/latest/meta-data/local-ipv4", headers=meta_headers, timeout=2).text
    except Exception as e:
        print(f"Error fetching IMDSv2 metadata: {e}")
    return metadata

def get_db_connection():
    # Split host and port if port is included
    host_parts = DB_HOST.split(':')
    host = host_parts[0]
    port = int(host_parts[1]) if len(host_parts) > 1 else 3306
    
    return pymysql.connect(
        host=host,
        port=port,
        user=DB_USER,
        password=DB_PASS,
        database=DB_NAME,
        cursorclass=pymysql.cursors.DictCursor,
        connect_timeout=3
    )

# Bootstrap DB tables
def init_db():
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS guestbook (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    name VARCHAR(100) NOT NULL,
                    message TEXT NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            conn.commit()
        conn.close()
        return "Connected"
    except Exception as e:
        print(f"DB Init Error: {e}")
        return str(e)

# Generate S3 Pre-signed URL for logo
def get_s3_image_url():
    s3_client = boto3.client('s3', region_name=AWS_REGION)
    try:
        # Check if the bucket and file exist
        s3_client.head_object(Bucket=S3_BUCKET, Key="logo.png")
        # Generate URL
        response = s3_client.generate_presigned_url(
            'get_object',
            Params={'Bucket': S3_BUCKET, 'Key': 'logo.png'},
            ExpiresIn=3600
        )
        return response, "Connected"
    except ClientError as e:
        print(f"S3 access error: {e}")
        return None, f"Error: {e}"
    except Exception as e:
        print(f"S3 generic error: {e}")
        return None, str(e)

@app.route("/", methods=["GET", "POST"])
def index():
    db_status = init_db()
    s3_url, s3_status = get_s3_image_url()
    metadata = get_ec2_metadata()
    messages = []
    
    if db_status == "Connected":
        try:
            conn = get_db_connection()
            if request.method == "POST":
                name = request.form.get("name", "Anonymous")
                msg = request.form.get("message", "")
                if msg:
                    with conn.cursor() as cursor:
                        cursor.execute(
                            "INSERT INTO guestbook (name, message) VALUES (%s, %s)",
                            (name, msg)
                        )
                    conn.commit()
                return redirect(url_for("index"))
            
            with conn.cursor() as cursor:
                cursor.execute("SELECT name, message, DATE_FORMAT(created_at, '%Y-%m-%d %H:%i:%s') as date FROM guestbook ORDER BY id DESC")
                messages = cursor.fetchall()
            conn.close()
        except Exception as e:
            db_status = f"Database Error: {e}"
            
    return render_template(
        "index.html",
        db_status=db_status,
        s3_status=s3_status,
        s3_url=s3_url,
        metadata=metadata,
        messages=messages,
        s3_bucket=S3_BUCKET
    )

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)

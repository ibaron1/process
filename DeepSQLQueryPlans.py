import os
import smtplib
import pyodbc
from email.message import EmailMessage
from lxml import etree
from datetime import datetime

# === CONFIGURATION ===
server = 'YOUR_SQL_SERVER'
database = 'YOUR_DATABASE'
output_folder = r'C:\QueryPlans'

smtp_server = 'smtp.yourdomain.com'
smtp_port = 587
smtp_user = 'your_email@yourdomain.com'
smtp_pass = 'your_email_password'
email_from = smtp_user
email_to = 'recipient@yourdomain.com'
email_subject = '⚠️ Deep SQL Query Plans Detected'
email_body = 'Attached are query plans that exceeded 128 XML node levels.'
# =====================

# Ensure output folder exists
os.makedirs(output_folder, exist_ok=True)

# Connect to SQL Server
conn_str = (
    f'DRIVER={{ODBC Driver 17 for SQL Server}};'
    f'SERVER={server};DATABASE={database};Trusted_Connection=yes;'
)
conn = pyodbc.connect(conn_str)
cursor = conn.cursor()

# Get raw plans
cursor.execute("SELECT id, session_id, plan_binary FROM dbo.DeepQueryPlans")
plans = cursor.fetchall()

deep_plans = []

# Function to calculate max XML depth
def get_max_depth(elem, depth=1):
    if len(elem) == 0:
        return depth
    return max(get_max_depth(child, depth + 1) for child in elem)

# Analyze plans
for row in plans:
    plan_id = row.id
    session_id = row.session_id
    binary_data = row.plan_binary

    try:
        xml_text = binary_data.decode('utf-16')
        xml_root = etree.fromstring(xml_text.encode('utf-8'))

        depth = get_max_depth(xml_root)
        print(f"Session {session_id}: Depth = {depth}")

        if depth > 128:
            file_path = os.path.join(output_folder, f'plan_{session_id}.sqlplan')
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(xml_text)
            deep_plans.append(file_path)
    except Exception as e:
        print(f"[!] Failed to parse plan for session {session_id}: {e}")

# Send email if any deep plans found
if deep_plans:
    print(f"📬 Sending email with {len(deep_plans)} .sqlplan files...")

    msg = EmailMessage()
    msg['From'] = email_from
    msg['To'] = email_to
    msg['Subject'] = email_subject
    msg.set_content(email_body)

    for file_path in deep_plans:
        with open(file_path, 'rb') as f:
            file_data = f.read()
            file_name = os.path.basename(file_path)
            msg.add_attachment(file_data, maintype='application', subtype='xml', filename=file_name)

    try:
        with smtplib.SMTP(smtp_server, smtp_port) as smtp:
            smtp.starttls()
            smtp.login(smtp_user, smtp_pass)
            smtp.send_message(msg)
        print("✅ Email sent successfully.")
    except Exception as e:
        print(f"[!] Failed to send email: {e}")
else:
    print("✅ No deep plans found. No email sent.")

# Cleanup
cursor.close()
conn.close()

"""
# app/notify.py
import os
import smtplib
from email.mime.text import MIMEText
from typing import List
from . import utils

SMTP_HOST = os.environ.get("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.environ.get("SMTP_PORT", 587))
SMTP_USER = os.environ.get("SMTP_USER", "")   # set in env
SMTP_PASS = os.environ.get("SMTP_PASS", "")   # set in env
FROM = SMTP_USER

def send_mail_sync(to_emails: List[str], subject: str, body: str):
    if not SMTP_USER or not SMTP_PASS:
        print("SMTP not configured; skipping send_mail")
        return
    msg = MIMEText(body)
    msg["Subject"] = subject
    msg["From"] = FROM
    msg["To"] = ", ".join(to_emails if isinstance(to_emails, list) else [to_emails])
    s = smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=10)
    s.starttls()
    s.login(SMTP_USER, SMTP_PASS)
    s.sendmail(FROM, to_emails, msg.as_string())
    s.quit()
"""
import json
import smtplib
import sys
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText


def main() -> int:
    payload = json.loads(sys.stdin.read())

    username = payload["username"].strip()
    password = payload["password"].strip()
    from_email = payload["from_email"].strip()
    to_email = payload["to_email"].strip()
    subject = payload["subject"]
    html = payload["html"]

    message = MIMEMultipart("alternative")
    message["Subject"] = subject
    message["From"] = from_email
    message["To"] = to_email
    message.attach(MIMEText(html, "html", "utf-8"))

    server = smtplib.SMTP("smtp.gmail.com", 587, timeout=20)
    try:
        server.ehlo()
        server.starttls()
        server.ehlo()
        server.login(username, password)
        server.sendmail(from_email, [to_email], message.as_string())
    finally:
        server.quit()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

import os
import socket

from flask import Flask, jsonify

app = Flask(__name__)

APP_ENV = os.getenv("APP_ENV", "on-premises")
APP_VERSION = os.getenv("APP_VERSION", "1.0.0")


@app.route("/")
def index():
    return jsonify(
        {
            "application": "workload-migration-poc",
            "environment": APP_ENV,
            "hostname": socket.gethostname(),
            "version": APP_VERSION,
        }
    )


@app.route("/health")
def health():
    return jsonify({"status": "healthy"}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("APP_PORT", 5000)))

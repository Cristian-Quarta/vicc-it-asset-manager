from flask import Flask, render_template, jsonify

app = Flask(__name__)

assets = [
    {
        "id": 1,
        "hostname": "SRV-APP01",
        "type": "Server",
        "os": "Windows Server 2022",
        "ip": "10.20.1.15",
        "location": "Bern",
        "status": "Online"
    },
    {
        "id": 2,
        "hostname": "CLIENT-001",
        "type": "Client",
        "os": "Windows 11",
        "ip": "10.20.1.101",
        "location": "Bern",
        "status": "Offline"
    }
]


@app.route("/")
def index():
    return render_template("index.html", assets=assets)


@app.route("/api/assets")
def get_assets():
    return jsonify(assets)


if __name__ == "__main__":
    app.run(debug=True)
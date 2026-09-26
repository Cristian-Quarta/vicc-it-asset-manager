from flask import Flask, render_template, jsonify, request, redirect, url_for

app = Flask(__name__)

# Temporäre Asset-Daten
# Diese werden später durch PostgreSQL ersetzt.
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


# Startseite
@app.route("/")
def index():
    return render_template("index.html", assets=assets)


# Neues Asset hinzufügen
@app.route("/add", methods=["GET", "POST"])
def add_asset():
    if request.method == "POST":

        new_asset = {
            "id": max([asset["id"] for asset in assets], default=0) + 1,
            "hostname": request.form["hostname"],
            "type": request.form["type"],
            "os": request.form["os"],
            "ip": request.form["ip"],
            "location": request.form["location"],
            "status": request.form["status"]
        }

        assets.append(new_asset)

        return redirect(url_for("index"))

    return render_template("add.html")


# Asset bearbeiten
@app.route("/edit/<int:asset_id>", methods=["GET", "POST"])
def edit_asset(asset_id):

    asset = next(
        (asset for asset in assets if asset["id"] == asset_id),
        None
    )

    if asset is None:
        return "Asset nicht gefunden", 404

    if request.method == "POST":

        asset["hostname"] = request.form["hostname"]
        asset["type"] = request.form["type"]
        asset["os"] = request.form["os"]
        asset["ip"] = request.form["ip"]
        asset["location"] = request.form["location"]
        asset["status"] = request.form["status"]

        return redirect(url_for("index"))

    return render_template("edit.html", asset=asset)


# Asset löschen
@app.route("/delete/<int:asset_id>", methods=["POST"])
def delete_asset(asset_id):

    asset = next(
        (asset for asset in assets if asset["id"] == asset_id),
        None
    )

    if asset is None:
        return "Asset nicht gefunden", 404

    assets.remove(asset)

    return redirect(url_for("index"))


# REST-API: Alle Assets anzeigen
@app.route("/api/assets")
def get_assets():
    return jsonify(assets)


# REST-API: Einzelnes Asset anzeigen
@app.route("/api/assets/<int:asset_id>")
def get_asset(asset_id):

    asset = next(
        (asset for asset in assets if asset["id"] == asset_id),
        None
    )

    if asset is None:
        return jsonify({"error": "Asset not found"}), 404

    return jsonify(asset)


if __name__ == "__main__":
    app.run(debug=True)

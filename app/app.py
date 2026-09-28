import os

from flask import Flask, render_template, jsonify, request, redirect, url_for
from flask_sqlalchemy import SQLAlchemy

app = Flask(__name__)

# Datenbankverbindung
# Lokal verwenden wir PostgreSQL auf Kali.
# Später wird DATABASE_URL von Azure bereitgestellt.
DATABASE_URL = os.getenv("DATABASE_URL")

if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL environment variable is not set")

app.config["SQLALCHEMY_DATABASE_URI"] = DATABASE_URL
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db = SQLAlchemy(app)


# Datenbankmodell
class Asset(db.Model):
    __tablename__ = "assets"

    id = db.Column(db.Integer, primary_key=True)
    hostname = db.Column(db.String(100), nullable=False)
    type = db.Column(db.String(50), nullable=False)
    os = db.Column(db.String(100))
    ip = db.Column(db.String(50))
    location = db.Column(db.String(100))
    status = db.Column(db.String(50), nullable=False)

    def to_dict(self):
        return {
            "id": self.id,
            "hostname": self.hostname,
            "type": self.type,
            "os": self.os,
            "ip": self.ip,
            "location": self.location,
            "status": self.status
        }


# Startseite
@app.route("/")
def index():
    assets = Asset.query.order_by(Asset.id).all()

    return render_template(
        "index.html",
        assets=assets
    )


# Neues Asset hinzufügen
@app.route("/add", methods=["GET", "POST"])
def add_asset():

    if request.method == "POST":

        new_asset = Asset(
            hostname=request.form["hostname"],
            type=request.form["type"],
            os=request.form["os"],
            ip=request.form["ip"],
            location=request.form["location"],
            status=request.form["status"]
        )

        db.session.add(new_asset)
        db.session.commit()

        return redirect(url_for("index"))

    return render_template("add.html")


# Asset bearbeiten
@app.route("/edit/<int:asset_id>", methods=["GET", "POST"])
def edit_asset(asset_id):

    asset = db.session.get(Asset, asset_id)

    if asset is None:
        return "Asset nicht gefunden", 404

    if request.method == "POST":

        asset.hostname = request.form["hostname"]
        asset.type = request.form["type"]
        asset.os = request.form["os"]
        asset.ip = request.form["ip"]
        asset.location = request.form["location"]
        asset.status = request.form["status"]

        db.session.commit()

        return redirect(url_for("index"))

    return render_template(
        "edit.html",
        asset=asset
    )


# Asset löschen
@app.route("/delete/<int:asset_id>", methods=["POST"])
def delete_asset(asset_id):

    asset = db.session.get(Asset, asset_id)

    if asset is None:
        return "Asset nicht gefunden", 404

    db.session.delete(asset)
    db.session.commit()

    return redirect(url_for("index"))


# REST-API: Alle Assets
@app.route("/api/assets")
def get_assets():

    assets = Asset.query.order_by(Asset.id).all()

    return jsonify([
        asset.to_dict()
        for asset in assets
    ])


# REST-API: Einzelnes Asset
@app.route("/api/assets/<int:asset_id>")
def get_asset(asset_id):

    asset = db.session.get(Asset, asset_id)

    if asset is None:
        return jsonify({
            "error": "Asset not found"
        }), 404

    return jsonify(asset.to_dict())


# Datenbanktabellen erstellen
with app.app_context():
    db.create_all()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)

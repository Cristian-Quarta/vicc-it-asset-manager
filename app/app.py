"""
VICC IT Asset Manager
---------------------
Flask-Webanwendung zur Verwaltung von IT-Assets.

Die Anwendung stellt eine Weboberfläche für einfache CRUD-Operationen
(Create, Read, Update, Delete) sowie eine REST-API zum Abrufen der
gespeicherten Assets bereit.

Die Daten werden über SQLAlchemy in einer PostgreSQL-Datenbank gespeichert.
Die Datenbankverbindung wird über die Umgebungsvariable DATABASE_URL
konfiguriert. Dadurch kann dieselbe Anwendung sowohl lokal als auch
in Microsoft Azure betrieben werden.
"""

import os

from flask import Flask, render_template, jsonify, request, redirect, url_for
from flask_sqlalchemy import SQLAlchemy


# ---------------------------------------------------------------------------
# Flask-Anwendung
# ---------------------------------------------------------------------------

# Erstellt die zentrale Flask-Anwendungsinstanz.
app = Flask(__name__)


# ---------------------------------------------------------------------------
# Datenbankkonfiguration
# ---------------------------------------------------------------------------

# Die Datenbank-Verbindungszeichenfolge wird aus der Umgebungsvariable
# DATABASE_URL gelesen.
#
# Dadurch werden keine Zugangsdaten direkt im Quellcode gespeichert.
# Lokal kann DATABASE_URL auf die PostgreSQL-Instanz auf Kali zeigen.
# In Azure wird die Variable als Secret an die Container App übergeben.
DATABASE_URL = os.getenv("DATABASE_URL")

# Ohne konfigurierte Datenbankverbindung kann die Anwendung nicht
# ordnungsgemäss gestartet werden. Deshalb wird der Start in diesem Fall
# mit einer eindeutigen Fehlermeldung abgebrochen.
if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL environment variable is not set")

# SQLAlchemy verwendet DATABASE_URL für die Verbindung zu PostgreSQL.
app.config["SQLALCHEMY_DATABASE_URI"] = DATABASE_URL

# Die Änderungsverfolgung von Flask-SQLAlchemy wird deaktiviert,
# da sie für diese Anwendung nicht benötigt wird.
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

# Initialisiert SQLAlchemy und verbindet es mit der Flask-Anwendung.
db = SQLAlchemy(app)


# ---------------------------------------------------------------------------
# Datenbankmodell
# ---------------------------------------------------------------------------

class Asset(db.Model):
    """
    Repräsentiert ein IT-Asset in der PostgreSQL-Datenbank.

    Jedes Asset besitzt eine eindeutige ID sowie grundlegende technische
    Informationen wie Hostname, Typ, Betriebssystem, IP-Adresse,
    Standort und Status.
    """

    # Name der Tabelle innerhalb der PostgreSQL-Datenbank.
    __tablename__ = "assets"

    # Primärschlüssel des Assets.
    id = db.Column(db.Integer, primary_key=True)

    # Hostname, Typ und Status sind Pflichtfelder.
    hostname = db.Column(db.String(100), nullable=False)
    type = db.Column(db.String(50), nullable=False)

    # Betriebssystem, IP-Adresse und Standort sind optionale Felder.
    os = db.Column(db.String(100))
    ip = db.Column(db.String(50))
    location = db.Column(db.String(100))

    status = db.Column(db.String(50), nullable=False)

    def to_dict(self):
        """
        Konvertiert ein Asset-Objekt in ein Python-Dictionary.

        Diese Darstellung wird von der REST-API verwendet, damit Flask
        die Asset-Daten anschliessend als JSON zurückgeben kann.
        """
        return {
            "id": self.id,
            "hostname": self.hostname,
            "type": self.type,
            "os": self.os,
            "ip": self.ip,
            "location": self.location,
            "status": self.status
        }


# ---------------------------------------------------------------------------
# Weboberfläche
# ---------------------------------------------------------------------------

@app.route("/")
def index():
    """
    Zeigt die Startseite des IT Asset Managers an.

    Alle vorhandenen Assets werden aus der Datenbank gelesen,
    nach ihrer ID sortiert und an das HTML-Template übergeben.
    """
    assets = Asset.query.order_by(Asset.id).all()

    return render_template(
        "index.html",
        assets=assets
    )


@app.route("/add", methods=["GET", "POST"])
def add_asset():
    """
    Erstellt ein neues IT-Asset.

    GET:
        Zeigt das Formular zum Erfassen eines Assets an.

    POST:
        Liest die Formulardaten aus, erstellt einen neuen
        Datenbankeintrag und leitet anschliessend auf die
        Startseite zurück.
    """

    if request.method == "POST":

        new_asset = Asset(
            hostname=request.form["hostname"],
            type=request.form["type"],
            os=request.form["os"],
            ip=request.form["ip"],
            location=request.form["location"],
            status=request.form["status"]
        )

        # Neues Asset zur aktuellen Datenbanksitzung hinzufügen
        # und dauerhaft in PostgreSQL speichern.
        db.session.add(new_asset)
        db.session.commit()

        return redirect(url_for("index"))

    return render_template("add.html")


@app.route("/edit/<int:asset_id>", methods=["GET", "POST"])
def edit_asset(asset_id):
    """
    Bearbeitet ein bestehendes IT-Asset.

    Die Asset-ID wird aus der URL übernommen. Existiert kein Asset
    mit dieser ID, wird HTTP-Statuscode 404 zurückgegeben.
    """

    # Sucht das Asset anhand seines Primärschlüssels.
    asset = db.session.get(Asset, asset_id)

    if asset is None:
        return "Asset nicht gefunden", 404

    if request.method == "POST":

        # Aktualisiert die Werte mit den Daten aus dem HTML-Formular.
        asset.hostname = request.form["hostname"]
        asset.type = request.form["type"]
        asset.os = request.form["os"]
        asset.ip = request.form["ip"]
        asset.location = request.form["location"]
        asset.status = request.form["status"]

        # Änderungen dauerhaft in PostgreSQL speichern.
        db.session.commit()

        return redirect(url_for("index"))

    return render_template(
        "edit.html",
        asset=asset
    )


@app.route("/delete/<int:asset_id>", methods=["POST"])
def delete_asset(asset_id):
    """
    Löscht ein bestehendes IT-Asset anhand seiner ID.

    Das Löschen ist nur über eine POST-Anfrage möglich.
    """

    asset = db.session.get(Asset, asset_id)

    if asset is None:
        return "Asset nicht gefunden", 404

    # Asset aus der Datenbank entfernen und Änderung speichern.
    db.session.delete(asset)
    db.session.commit()

    return redirect(url_for("index"))


# ---------------------------------------------------------------------------
# REST-API
# ---------------------------------------------------------------------------

@app.route("/api/assets")
def get_assets():
    """
    REST-Endpunkt zum Abrufen aller Assets.

    Die Daten werden als JSON zurückgegeben und können dadurch
    auch von anderen Anwendungen verarbeitet werden.
    """

    assets = Asset.query.order_by(Asset.id).all()

    return jsonify([
        asset.to_dict()
        for asset in assets
    ])


@app.route("/api/assets/<int:asset_id>")
def get_asset(asset_id):
    """
    REST-Endpunkt zum Abrufen eines einzelnen Assets.

    Wird keine passende ID gefunden, liefert die API einen
    HTTP-Statuscode 404 mit einer JSON-Fehlermeldung.
    """

    asset = db.session.get(Asset, asset_id)

    if asset is None:
        return jsonify({
            "error": "Asset not found"
        }), 404

    return jsonify(asset.to_dict())


# ---------------------------------------------------------------------------
# Initialisierung der Datenbank
# ---------------------------------------------------------------------------

# Erstellt beim Start der Anwendung alle noch nicht vorhandenen Tabellen
# anhand der definierten SQLAlchemy-Modelle.
#
# Bereits vorhandene Tabellen und Daten werden dabei nicht gelöscht.
with app.app_context():
    db.create_all()


# ---------------------------------------------------------------------------
# Lokaler Start der Anwendung
# ---------------------------------------------------------------------------

# Dieser Block wird nur ausgeführt, wenn app.py direkt mit Python gestartet
# wird. Durch 0.0.0.0 ist die Anwendung auch ausserhalb des lokalen
# Loopback-Interfaces erreichbar, was insbesondere für Docker erforderlich ist.
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)

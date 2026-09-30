# ---------------------------------------------------------------------------
# VICC IT Asset Manager - Docker Image
# ---------------------------------------------------------------------------
# Als Basis wird ein schlankes offizielles Python-Image verwendet.
# Die Slim-Variante reduziert die Grösse des resultierenden Container-Images.
FROM python:3.14-slim


# Definiert /app als Arbeitsverzeichnis innerhalb des Containers.
# Alle folgenden Befehle werden relativ zu diesem Verzeichnis ausgeführt.
WORKDIR /app


# Kopiert zuerst nur die Python-Abhängigkeiten in den Container.
# Dadurch kann Docker diesen Layer beim erneuten Build wiederverwenden,
# solange sich die requirements.txt nicht verändert hat.
COPY app/requirements.txt .


# Installiert alle für die Flask-Anwendung benötigten Python-Pakete.
# --no-cache-dir verhindert, dass der pip-Download-Cache im Image
# gespeichert wird und hält das Container-Image dadurch kleiner.
RUN pip install --no-cache-dir -r requirements.txt


# Kopiert anschliessend den vollständigen Anwendungscode
# aus dem lokalen Verzeichnis app/ in das Arbeitsverzeichnis /app.
COPY app/ .


# Dokumentiert, dass die Flask-Anwendung innerhalb des Containers
# den TCP-Port 5000 verwendet.
EXPOSE 5000


# Startbefehl des Containers.
# Beim Start wird die Flask-Anwendung über app.py ausgeführt.
CMD ["python", "app.py"]

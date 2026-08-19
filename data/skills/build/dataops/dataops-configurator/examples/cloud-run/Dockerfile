# Ejemplo de Dockerfile para Cloud Run
# Fuente: itcm-inca-audience-campaign-loader-api/service/cloud_run/itc-campaign-loader-api
# Este es el PATRÓN CANÓNICO correcto: simple, single-stage, basado en python:3.11-slim

# Usa una imagen oficial de Python
FROM python:3.11-slim

# Establece el directorio de trabajo dentro del contenedor
WORKDIR /app

# Copia requirements.txt
COPY requirements.txt .

# Copia los archivos de tu app al contenedor
COPY src/main /app

# Instala dependencias
RUN pip install --no-cache-dir -r requirements.txt

# Expone el puerto usado por Uvicorn
EXPOSE 8080

# Comando para correr la app FastAPI
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]

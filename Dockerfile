FROM python:3.11-bullseye

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies and MS ODBC Driver 18
RUN apt-get update && apt-get install -y \
    curl gnupg2 apt-transport-https ca-certificates \
    unixodbc unixodbc-dev libunwind8 software-properties-common \
    && curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/microsoft.gpg \
    && echo "deb [arch=amd64] https://packages.microsoft.com/debian/11/prod bullseye main" > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y msodbcsql18 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*


# Set working directory
WORKDIR /app
# ----------------------------
# Copy app code
# ----------------------------
COPY  . .

# ----------------------------
# Install Python dependencies
# ----------------------------
RUN pip install --upgrade pip setuptools wheel \
 && pip install --no-cache-dir -r requirements.txt

# ----------------------------
# Expose port & run Chainlit
# ----------------------------
EXPOSE 8000
CMD ["chainlit", "run", "main.py", "--host", "0.0.0.0"]

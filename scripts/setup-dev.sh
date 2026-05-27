#!/usr/bin/env bash

set -e

echo "Actualizando sistema..."
sudo apt update
sudo apt upgrade -y

echo "Instalando herramientas base..."
sudo apt install -y \
  git \
  curl \
  wget \
  build-essential \
  python3 \
  python3-pip \
  nodejs \
  npm \
  ffmpeg \
  htop \
  tree \
  zip \
  unzip \
  live-build

echo "Entorno de desarrollo listo."

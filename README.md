# DESPLIEGUE DE SERVIDOR NGINX CON PHP EN AWS

Este proyecto tiene como objetivo desplegar una máquina virtual (instancia EC2) con Ubuntu 22.04 LTS en AWS utilizando **Terraform**, y luego configurarla como un servidor Nginx con soporte para PHP utilizando **Ansible**.
## 1. Prerrequisitos
Asegúrate de tener los siguientes componentes instalados y configurados antes de proceder:
- **Terraform CLI** (v1.2.0 o superior)
- **AWS CLI**
- **Ansible**
- **Una cuenta de AWS** con credenciales que permitan la creación de recursos.
### Instalación de AWS CLI
Para instalar AWS CLI usando Snap:

```bash
sudo snap install aws-cli --classic
```

Verifica la instalación con:

```bash
aws --version
```

Configura tu perfil en AWS generando dos tokens:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

Exporta estas credenciales en tu entorno:

```bash
export AWS_ACCESS_KEY_ID=AKI****
export AWS_SECRET_ACCESS_KEY=QvJG7*******
```
### Instalación de Ansible
Instala Ansible en tu máquina local:

```bash
sudo apt install ansible
```

### Creación de Key Pairs en AWS para SSH
Es necesario crear un par de claves (key pair) en AWS para acceder a la instancia EC2 de forma remota. Una vez creada, descarga el archivo `.pem` y colócalo en una ubicación segura en tu máquina local.
### Generación de Claves SSH Locales
Para acceder al servidor desde Ansible, genera claves SSH en tu máquina local:

```bash
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

Copia la clave pública y agrégala al archivo `authorized_keys` de la instancia EC2 en la ruta `/home/ubuntu/.ssh/`.

```bash
ssh -i path_to_key.pem ubuntu@<public_ip>
nano /home/ubuntu/.ssh/authorized_keys
```

Pega la clave pública generada localmente en este archivo.
## 2. Configuración de Terraform
### 2.1 Estructura de carpetas
La estructura de carpetas del proyecto es la siguiente:

```
root/
│
├── terraform/
│   └── main.tf
│
└── ansible/
    ├── ansible_vars.yaml
    ├── inventory.ini
    ├── nginx.conf.j2
    ├── playbook.yaml
    └── test.php
```
### 2.2 Configuración del archivo `main.tf`
El archivo `main.tf` define los recursos que Terraform aprovisionará en AWS. A continuación, un ejemplo básico:

```tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_security_group" "allow_http" {
  name        = "allow_http_traffic"
  description = "Allow HTTP traffic"
  
  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "AllowHTTP"
  }
}

resource "aws_instance" "app_server" {
  ami           = "ami-0a0e5d9c7acc336f1"  # Ubuntu 22.04 LTS AMI
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.allow_http.id]
  key_name = "michael-key-pairs"
  associate_public_ip_address = true
  tags = {
    Name = "ExampleAppServerInstance"
  }
}
```
### 2.3 Despliegue de la Instancia
Para desplegar la instancia EC2:

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

Una vez creada la instancia, su dirección IP pública será visible en la consola de AWS. También puedes usar el siguiente comando para obtenerla:

```bash
terraform output
```
## 3. Configuración de Ansible
### 3.1 Configuración del archivo `inventory.ini`
Modifica el archivo `inventory.ini` con la IP pública de la instancia EC2 creada y la ubicación de tu archivo de claves privadas (.pem):

```ini
[server]
<public_ip> ansible_user=ubuntu ansible_private_key_file=/path/to/michael-key-pairs.pem
```
### 3.2 Ejecución del Playbook de Ansible
El playbook `playbook.yaml` instala Nginx y PHP en la instancia EC2. Aquí un ejemplo del contenido:

```yaml
---
- name: Install Nginx Server
  hosts: all
  remote_user: ubuntu
  become: yes
  vars_files:
    - ansible_vars.yaml
  tasks:
    - name: Install Nginx and PHP Packages
      apt: name={{ item }} update_cache=yes state=latest
      loop: [ 'nginx', 'php-fpm' ]

    - name: Make sure Nginx service is running
      systemd:
        state: started
        name: nginx

    - name: Sets Nginx conf file
      template:
        src: "nginx.conf.j2"
        dest: "/etc/nginx/sites-available/{{ http_conf }}"

    - name: Enables new site
      file:
        src: "/etc/nginx/sites-available/{{ http_conf }}"
        dest: "/etc/nginx/sites-enabled/{{ http_conf }}"
        state: link
      notify: Reload Nginx

    - name: Removes "default" site
      file:
        path: "/etc/nginx/sites-enabled/default"
        state: absent
      notify: Restart Nginx

    - name: Sets Up PHP Info Page
      template:
        src: "test.php"
        dest: "/var/www/html/test.php"

  handlers:
    - name: Reload Nginx
      service:
        name: nginx
        state: reloaded

    - name: Restart Nginx
      service:
        name: nginx
        state: restarted
```
### 3.3 Verificación de Conexión
Prueba la conexión a la instancia EC2 desde Ansible:

```bash
ansible server -m ping -i inventory.ini
```

Si la conexión es exitosa, deberías ver una respuesta "pong".
### 3.4 Ejecutar el Playbook
Finalmente, ejecuta el playbook de Ansible:

```bash
ansible-playbook -i inventory.ini playbook.yaml
```
### 3.5 Prueba del Servidor
Dirígete a la dirección IP pública de la instancia y accede a `/test.php` para ver la página de información de PHP `http://<public_ip>/test.php`
## 4. Destrucción de Recursos
Para evitar costos adicionales, destruye la instancia EC2 una vez que termines:

```bash
terraform destroy -auto-approve
```

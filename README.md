# 🔐 MTLS CA Certificate Manager for AWS S3

Este projeto contém um **script em Bash** que automatiza a **gestão de certificados CA para clientes MTLS**, armazenados em buckets AWS S3.  
O objetivo é facilitar a **validação, configuração e atualização do truststore**, tanto em ambiente **HML** quanto **PRD**.

---

## 🚀 Funcionalidades

- 🧹 **Limpeza do diretório de certificados** (`Certs/`).
- ✅ **Validação de certificados CA**:
  - Verifica validade (anos restantes até expiração).
  - Verifica se é um certificado de cliente/servidor confiável.
  - Exibe **Common Name (CN)** e data de expiração.
- 📥 **Download do truststore** atual do bucket S3.
- 📤 **Upload e backup automático** do truststore antes de alterações.
- 🛠️ **Configuração de certificado para um cliente**:
  - Upload do certificado CA no bucket correspondente.
  - Atualização e versionamento do `truststore.pem`.
- 🛠️ **Configuração de certificados para múltiplos clientes**:
  - Itera sobre os certificados no diretório.
  - Faz upload para o bucket e atualiza o truststore em lote.
- 📜 **Relatórios claros** no terminal indicando sucesso ou falha de cada etapa.

---

## ⚙️ Estrutura do Projeto

- `script.sh` → Script principal.
- `Certs/` → Diretório de trabalho dos certificados (`.pem`).
- Buckets configurados no script:
  - **Homologação (HML):** `xpto-mtls-certs-hml`
  - **Produção (PRD):** `xpto-mtls-certs-prd`
- Arquivos principais:
  - `truststore.pem` → Truststore atual.
  - `truststore_<data>.pem` → Backup gerado com timestamp.



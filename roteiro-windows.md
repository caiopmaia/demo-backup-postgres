# Demonstração — Backup, Recuperação e Monitoramento no PostgreSQL (Windows)

Roteiro testado no PostgreSQL 16 (funciona do 12 em diante).
Arquivos: `preparar_banco.sql` (prepara o banco) e este roteiro.

---

## ANTES DA APRESENTAÇÃO (preparação, ninguém vê)

Abra o **PowerShell na pasta dos arquivos** (no Explorador, clique na barra de endereço, digite `powershell` e aperte Enter). Não use o "SQL Shell (psql)": de dentro dele não dá para rodar `pg_dump` nem `psql -f`.

Em **cada** janela do PowerShell que abrir (inclusive o Terminal B), rode primeiro (troque `16` pela sua versão):

```powershell
$env:Path += ";C:\Program Files\PostgreSQL\16\bin"
chcp 65001
$env:PGCLIENTENCODING = "UTF8"
```

A primeira linha faz o PowerShell achar o `psql` e o `pg_dump`. As outras duas evitam acentos bagunçados.

```bash
createdb -U postgres loja_demo
psql -U postgres -d loja_demo -f preparar_banco.sql
```

Deve aparecer: `Banco pronto: 5 clientes, 5 produtos, 8 pedidos.`

> Para ensaiar de novo, basta rodar só o segundo comando outra vez: ele apaga tudo (inclusive o usuário `leitor`) e recria do zero.

**Deixe abertos dois terminais lado a lado:**
- **Terminal A** — administrador (`postgres`)
- **Terminal B** — usuário só de leitura (`leitor`)

Dica: aumente a fonte do terminal para a turma conseguir ler.

---

## PASSO 1 — Menor privilégio (usuário só de leitura)

**Terminal A** — entre no banco como administrador:

```bash
psql -U postgres -d loja_demo
```

Crie o usuário e dê só permissão de leitura:

```sql
CREATE ROLE leitor LOGIN PASSWORD 'leitor123';
GRANT CONNECT ON DATABASE loja_demo TO leitor;
GRANT USAGE ON SCHEMA public TO leitor;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO leitor;
```

**Terminal B** — entre como o `leitor` (senha: `leitor123`):

```bash
psql -U leitor -h localhost -d loja_demo
```

Consulta funciona:

```sql
SELECT * FROM clientes;
```

Tentativa de apagar é recusada:

```sql
DELETE FROM clientes WHERE id = 1;
```

Resultado esperado:
```
ERROR:  permission denied for table clientes
```
(em instalação em português: `ERRO: permissão negada para tabela clientes`)

> **Fala:** "Como vocês podem ver, esse usuário consegue consultar, mas o banco recusa quando ele tenta apagar."

**Deixe o Terminal B aberto e conectado** — ele vai aparecer no monitoramento no passo 5.

---

## PASSO 2 — Backup

No **Terminal A**, saia do psql (`\q`) e rode:

```bash
pg_dump -U postgres -d loja_demo --clean --if-exists -f backup_loja.sql
```

Mostre que o arquivo foi criado (`dir backup_loja.sql` no Windows, `ls -l backup_loja.sql` no Linux/Mac). Se quiser, abra o arquivo rapidamente para mostrar os `CREATE TABLE` e os dados.

> **Fala:** "Esse comando gerou um arquivo SQL com todo o banco: a estrutura das tabelas, os dados e até as permissões."

*Por que `--clean --if-exists`?* Faz o backup apagar e recriar cada objeto na hora de restaurar. Sem isso, restaurar por cima do banco existente daria erros de "já existe" e duplicaria dados nas tabelas que não foram apagadas.

---

## PASSO 3 — Simulando o desastre

Ainda no **Terminal A**:

```bash
psql -U postgres -d loja_demo
```

```sql
SELECT count(*) FROM pedidos;   -- mostra que existem 8 pedidos
DROP TABLE pedidos;
SELECT * FROM pedidos;
```

Resultado esperado:
```
ERROR:  relation "pedidos" does not exist
```
(em português: `ERRO: relação "pedidos" não existe`)

> **Fala:** "A tabela sumiu. Se eu consultar, o banco diz que ela não existe. Sem backup, esses dados estariam perdidos."

*Atenção:* apague a tabela **pedidos**, não `clientes` — `clientes` é referenciada por `pedidos` (chave estrangeira) e o `DROP` daria erro.

---

## PASSO 4 — Restauração

Saia do psql (`\q`) e rode:

```bash
psql -U postgres -d loja_demo -q -f backup_loja.sql
```

Vão passar algumas linhas na tela (é normal). Depois confira:

```bash
psql -U postgres -d loja_demo
```

```sql
SELECT * FROM pedidos;
```

Os 8 pedidos voltaram.

> **Fala:** "Pronto. Se eu consultar de novo, a tabela voltou com todos os dados."

---

## PASSO 5 — Monitoramento

Ainda no **Terminal A** (dentro do psql):

```sql
SELECT pid,
       usename          AS usuario,
       datname          AS banco,
       client_addr      AS ip,
       state            AS estado,
       now() - query_start AS tempo,
       left(query, 50)  AS consulta
FROM pg_stat_activity
WHERE datname IS NOT NULL;
```

Vão aparecer **duas conexões**: a do `postgres` (você, executando esta consulta) e a do `leitor` (o Terminal B, parado em `idle`).

> **Fala:** "Essa consulta mostra quem está conectado no banco agora, o que cada conexão está executando e há quanto tempo. Aqui aparece o meu usuário administrador e também o usuário de leitura que criamos, que está conectado mas parado. É um exemplo simples de como o DBA acompanha o que está acontecendo."

---

## Se algo der errado na hora

| Problema | Solução |
|---|---|
| `psql` / `pg_dump` não é reconhecido (Windows) | Use o caminho completo: `"C:\Program Files\PostgreSQL\16\bin\psql.exe"` (troque 16 pela sua versão) ou abra o **SQL Shell (psql)** |
| Pede senha do `postgres` | É a senha definida na instalação do PostgreSQL |
| `role "leitor" already exists` | Rode de novo `preparar_banco.sql` (ele remove o usuário) |
| `database "loja_demo" already exists` no `createdb` | Ignore, o banco já está criado — só rode o `preparar_banco.sql` |
| Login do `leitor` falha | Confira se usou `-h localhost` no comando |

**Plano B:** grave a demo em vídeo no ensaio. Se o PC da sala der problema, mostra o vídeo.

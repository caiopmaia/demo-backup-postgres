# Demonstração — Backup, Recuperação e Monitoramento no PostgreSQL (macOS)

Roteiro para Mac usando o **Postgres.app** (funciona do PostgreSQL 12 em diante).
Arquivos: `preparar_banco.sql` (prepara o banco) e este roteiro.

---

## INSTALAÇÃO (só uma vez)

1. Baixe o Postgres.app em **postgresapp.com**, arraste para **Aplicativos** e abra.
2. Clique em **Initialize**. Vai aparecer um elefante na barra de menu, sinal de que o servidor está ligado.
3. Abra o **Terminal** e libere os comandos `psql`, `pg_dump` e `createdb`:

```bash
sudo mkdir -p /etc/paths.d && echo /Applications/Postgres.app/Contents/Versions/latest/bin | sudo tee /etc/paths.d/postgresapp
```

4. Feche o Terminal, abra de novo e confira:

```bash
psql --version
```

> No Postgres.app as conexões locais **não pedem senha**, nem para o `postgres` nem para o `leitor`. É normal e não atrapalha a demo.

---

## ANTES DA APRESENTAÇÃO (preparação, ninguém vê)

1. Confira se o elefante do Postgres.app está na barra de menu (servidor ligado).
2. No Terminal, entre na pasta dos arquivos (exemplo com a pasta `demo` na Mesa):

```bash
cd ~/Desktop/demo
```

Dica: digite `cd ` (com espaço), arraste a pasta do Finder para o Terminal e aperte Enter.

3. Crie e prepare o banco:

```bash
createdb -U postgres loja_demo
psql -U postgres -d loja_demo -f preparar_banco.sql
```

Deve aparecer: `Banco pronto: 5 clientes, 5 produtos, 8 pedidos.`

> Para ensaiar de novo, basta rodar só o segundo comando outra vez: ele apaga tudo (inclusive o usuário `leitor`) e recria do zero.

**Deixe duas janelas do Terminal lado a lado** (⌘N abre uma nova), as duas na pasta `demo`:
- **Terminal A**: administrador (`postgres`)
- **Terminal B**: usuário só de leitura (`leitor`)

Dica: aumente a fonte com **⌘ +** para a turma conseguir ler.

---

## PASSO 1 — Menor privilégio (usuário só de leitura)

**Terminal A**: entre no banco como administrador:

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

**Terminal B**: entre como o `leitor`:

```bash
psql -U leitor -h localhost -d loja_demo
```

A consulta funciona:

```sql
SELECT * FROM clientes;
```

A tentativa de apagar é recusada:

```sql
DELETE FROM clientes WHERE id = 1;
```

Resultado esperado:
```
ERROR:  permission denied for table clientes
```

> **Fala:** "Como vocês podem ver, esse usuário consegue consultar, mas o banco recusa quando ele tenta apagar."

**Deixe o Terminal B aberto e conectado.** Ele vai aparecer no monitoramento no passo 5.

*Se alguém perguntar por que não pediu senha:* "Neste ambiente de teste o acesso local está liberado, mas em produção o login exige senha. O que estamos mostrando aqui são as permissões, e elas continuam valendo: o usuário entra, mas só pode ler."

---

## PASSO 2 — Backup

No **Terminal A**, saia do psql (`\q`) e rode:

```bash
pg_dump -U postgres -d loja_demo --clean --if-exists -f backup_loja.sql
ls -l backup_loja.sql
```

Se quiser mostrar o conteúdo rapidamente:

```bash
open -e backup_loja.sql
```

(abre o arquivo no TextEdit, com os `CREATE TABLE` e os dados)

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

> **Fala:** "A tabela sumiu. Se eu consultar, o banco diz que ela não existe. Sem backup, esses dados estariam perdidos."

*Atenção:* apague a tabela **pedidos**, não `clientes`. A `clientes` é referenciada por `pedidos` (chave estrangeira), e o `DROP` dela daria erro.

---

## PASSO 4 — Restauração

Saia do psql (`\q`) e rode:

```bash
psql -U postgres -d loja_demo -q -f backup_loja.sql
```

Vão passar algumas linhas na tela, é normal. Depois confira:

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

Se a tabela ficar larga demais e quebrar na tela, rode `\x` antes da consulta: o resultado aparece em formato vertical, uma conexão por bloco.

---

## Se algo der errado na hora

| Problema | Solução |
|---|---|
| `command not found: psql` | Refaça o passo 3 da instalação e **reabra o Terminal** |
| `could not connect to server` / `Connection refused` | O Postgres.app está fechado ou parado: abra o app e clique em **Start** |
| `role "postgres" does not exist` | Rode `createuser -s postgres` (acontece quando o PostgreSQL foi instalado pelo Homebrew) |
| `role "leitor" already exists` | Rode de novo o `preparar_banco.sql` (ele remove o usuário) |
| `database "loja_demo" already exists` no `createdb` | Ignore, o banco já existe. Só rode o `preparar_banco.sql` |
| `No such file or directory` no `-f` | Você não está na pasta dos arquivos: rode o `cd` de novo |
| O resultado ocupa a tela e fica preso com `:` no final | Aperte **q** para sair da paginação |

**Plano B:** grave a demo no ensaio (⌘ Shift 5 grava a tela no Mac). Se der problema na hora, mostre o vídeo.

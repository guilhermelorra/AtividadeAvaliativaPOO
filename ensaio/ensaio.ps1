<#
.SYNOPSIS
  Ensaio da demonstração do SGA: recria o banco, abre o app e conduz o roteiro passo a passo.

.DESCRIPTION
  1. Pede a senha do MySQL (não grava em lugar nenhum) e testa a conexão.
  2. Recria o banco sga_fbi do zero com database\SGA_completo.sql e confere os 39 testes.
  3. Compila e abre o app (usa o Maven se existir; senão compila com o javac e as
     bibliotecas que já estão em ~\.m2).
  4. Mostra o roteiro da demonstração, um passo por vez.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File ensaio\ensaio.ps1

.EXAMPLE
  # só preparar o banco e compilar, sem abrir o app nem o roteiro
  powershell -ExecutionPolicy Bypass -File ensaio\ensaio.ps1 -SoPreparar
#>
param(
    [string]$Usuario = 'root',
    [string]$Servidor = '127.0.0.1',
    [int]$Porta = 3306,
    [string]$Senha,          # só para testes automáticos; normalmente deixe em branco e digite quando pedir
    [switch]$SoPreparar,     # recria o banco e compila, mas não abre o app nem o roteiro
    [switch]$SemReset,       # não recria o banco (usa como está)
    [switch]$Sim             # não pede confirmação antes de apagar o banco
)

$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

function Titulo($t) { Write-Host ''; Write-Host "== $t" -ForegroundColor Cyan }
function Ok($t)     { Write-Host "  [ok] $t" -ForegroundColor Green }
function Aviso($t)  { Write-Host "  [!]  $t" -ForegroundColor Yellow }
function Falha($t)  { Write-Host "  [x]  $t" -ForegroundColor Red }

# ---------------------------------------------------------------- mysql.exe
function Achar-Mysql {
    $cmd = Get-Command mysql.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $achados = Get-ChildItem 'C:\Program Files\MySQL\MySQL Server *\bin\mysql.exe' -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending
    if ($achados) { return $achados[0].FullName }
    return $null
}

$mysql = Achar-Mysql
if (-not $mysql) { Falha 'mysql.exe não encontrado. Instale o MySQL ou abra o SGA_completo.sql no Workbench.'; exit 1 }

# ---------------------------------------------------------------- senha
if ($PSBoundParameters.ContainsKey('Senha')) {
    $senhaTexto = $Senha
} else {
    $seg = Read-Host "Senha do MySQL para o usuário '$Usuario' (não fica gravada)" -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($seg)
    try { $senhaTexto = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

$env:MYSQL_PWD = $senhaTexto
$env:SGA_DB_USER = $Usuario
$env:SGA_DB_PASSWORD = $senhaTexto
$env:SGA_DB_URL = "jdbc:mysql://${Servidor}:${Porta}/sga_fbi?serverTimezone=America/Cuiaba"

function Mysql-Rodar([string]$sql) {
    & $mysql "-u$Usuario" "-h$Servidor" "-P$Porta" '--default-character-set=utf8mb4' -e $sql 2>&1
}

try {
    # ------------------------------------------------------------ conexão
    Titulo 'Conexão com o MySQL'
    $teste = Mysql-Rodar 'SELECT VERSION() AS versao;' | Out-String
    if ($LASTEXITCODE -ne 0) {
        Falha ('Não conectei em ' + $Servidor + ':' + $Porta + ' com o usuário ' + $Usuario + '.')
        Write-Host $teste
        Aviso 'Confira se o MySQL está ligado (serviço MySQL80) e se a senha está certa.'
        exit 1
    }
    Ok ('Conectado em ' + $Servidor + ':' + $Porta + ' (' + ($teste -split "`n")[1].Trim() + ')')

    # ------------------------------------------------------------ banco
    if ($SemReset) {
        Aviso 'Mantendo o banco como está (-SemReset).'
    } else {
        Titulo 'Recriar o banco sga_fbi'
        $existe = (Mysql-Rodar "SHOW DATABASES LIKE 'sga_fbi';" | Out-String).Trim()
        if ($existe) { Aviso 'O banco sga_fbi já existe e será APAGADO e recriado do zero.' }
        if (-not $Sim) {
            $r = Read-Host 'Continuar? (s/N)'
            if ($r -notmatch '^[sS]') { Aviso 'Cancelado. Nada foi alterado.'; exit 0 }
        }
        $script = (Join-Path $raiz 'database\SGA_completo.sql') -replace '\\', '/'
        $saida = & $mysql "-u$Usuario" "-h$Servidor" "-P$Porta" '--default-character-set=utf8mb4' -e "source $script" 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { Falha 'O SGA_completo.sql deu erro:'; Write-Host $saida; exit 1 }
        Ok 'SGA_completo.sql executado sem erro.'

        $resumo = ($saida -split "`r?`n" | Where-Object { $_ -match '^\d+\t\d+\t\d+$' } | Select-Object -Last 1)
        if ($resumo) {
            $p = $resumo -split "`t"
            if ([int]$p[1] -eq 0) { Ok ("Testes do banco: {0} OK, {1} falhas, {2} no total." -f $p[0], $p[1], $p[2]) }
            else { Falha ("Testes do banco: {0} OK, {1} FALHARAM." -f $p[0], $p[1]) }
        }
        $n = (Mysql-Rodar 'SELECT COUNT(*) FROM sga_fbi.matricula;' | Select-Object -Last 1).Trim()
        Ok "Matrículas no banco: $n (esperado: 35)"
    }

    # ------------------------------------------------------------ compilar
    Titulo 'Compilar o app'
    $app = Join-Path $raiz 'app'
    $m2 = Join-Path $env:USERPROFILE '.m2\repository'
    $jarMysql = Get-ChildItem (Join-Path $m2 'com\mysql\mysql-connector-j') -Recurse -Filter 'mysql-connector-j-*.jar' -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
    $jarFlat = Get-ChildItem (Join-Path $m2 'com\formdev\flatlaf') -Recurse -Filter 'flatlaf-3*.jar' -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
    $classes = Join-Path $app 'target\ensaio-classes'
    $cp = $null

    $mvn = Get-Command mvn -ErrorAction SilentlyContinue
    $javac = Get-Command javac.exe -ErrorAction SilentlyContinue
    if (-not $javac -and $env:JAVA_HOME) { $javac = Get-Command (Join-Path $env:JAVA_HOME 'bin\javac.exe') -ErrorAction SilentlyContinue }

    if ($mvn) {
        Push-Location $app
        try { & mvn -q -B clean compile 2>&1 | Out-Host; if ($LASTEXITCODE -ne 0) { throw 'mvn falhou' } } finally { Pop-Location }
        Ok 'Compilado com o Maven.'
        $classes = Join-Path $app 'target\classes'
    } elseif ($javac -and $jarMysql -and $jarFlat) {
        if (Test-Path $classes) { Remove-Item -Recurse -Force $classes }
        New-Item -ItemType Directory -Path $classes | Out-Null
        $fontes = Get-ChildItem (Join-Path $app 'src\main\java') -Recurse -Filter '*.java' | ForEach-Object { $_.FullName }
        $cpLib = $jarMysql.FullName + ';' + $jarFlat.FullName
        & $javac.Source -encoding UTF-8 -cp $cpLib -d $classes $fontes 2>&1 | Out-Host
        if ($LASTEXITCODE -ne 0) { Falha 'Erro ao compilar.'; exit 1 }
        Ok 'Compilado com o javac (sem Maven).'
    } else {
        Falha 'Não achei o Maven nem o conjunto javac + bibliotecas do .m2.'
        Aviso 'Abra a pasta app no IntelliJ, rode a classe SgaApplication e coloque SGA_DB_USER e SGA_DB_PASSWORD em "Environment variables".'
        exit 1
    }
    if (-not $jarMysql -or -not $jarFlat) {
        Aviso 'Bibliotecas não encontradas em ~\.m2; o app só abre se o Maven estiver no PATH.'
    }
    $cp = $classes + ';' + $jarMysql.FullName + ';' + $jarFlat.FullName

    if ($SoPreparar) { Titulo 'Pronto (modo -SoPreparar): banco recriado e app compilado.'; exit 0 }

    # ------------------------------------------------------------ abrir o app
    Titulo 'Abrir o app'
    $java = Get-Command java.exe -ErrorAction SilentlyContinue
    if (-not $java) { Falha 'java.exe não encontrado (instale o JDK 17).'; exit 1 }
    $proc = Start-Process -FilePath $java.Source -ArgumentList @('-Dfile.encoding=UTF-8', '-cp', "`"$cp`"", 'br.edu.fbi.sga.SgaApplication') -PassThru
    Ok ('App aberto (processo ' + $proc.Id + '). Senha de todos os usuários de teste: Senha@123')

    # ------------------------------------------------------------ roteiro
    $passos = @(
        @{ Quem = 'coord.ana, senha errada';  Faca = 'Digite uma senha errada e clique em Entrar.';
           Deve = 'Aparece "Login ou senha inválidos." (sem dizer qual campo errou).' },
        @{ Quem = 'sec.carla';                Faca = 'Entre e olhe o menu e o painel Início.';
           Deve = 'Menu sem Notas e exame, Fechar semestre, Relatórios e Auditoria; painel sem o cartão de faturamento.' },
        @{ Quem = 'sec.carla';                Faca = 'Menu Matricular: aluno Rafael Domingues, turma Estruturas de Dados.';
           Deve = '"Falta pré-requisito: o aluno não foi aprovado em Algoritmos." (quem decidiu foi o banco).' },
        @{ Quem = 'sec.carla';                Faca = 'Menu Matricular: aluno Queila Macedo, turma Banco de Dados.';
           Deve = '"Matrícula realizada com sucesso!"' },
        @{ Quem = 'sec.carla';                Faca = 'Menu Histórico, aluno 3.';
           Deve = 'Histórico com o CR do aluno no topo.' },
        @{ Quem = 'coord.ana';                Faca = 'Notas e exame, turma de Programação Orientada a Objetos: Daniel Pacheco, N1 7,5, N2 8 e 3 faltas.';
           Deve = 'Média 7,75 e situação Aprovado aparecem na hora.' },
        @{ Quem = 'coord.ana';                Faca = 'Na mesma tela, Bernardo Cavalcante (Em Exame): lançar exame 5.';
           Deve = 'Média final 5,75 e Aprovado.' },
        @{ Quem = 'coord.ana';                Faca = 'Menu Auditoria.';
           Deve = 'Linhas novas: quem mudou, qual campo, valor antigo e novo (o trigger funcionando).' },
        @{ Quem = 'coord.ana';                Faca = 'Menu Fechar semestre, 2026.2.';
           Deve = 'Recusado: "Matrícula 17 (Alice Monteiro) sem N1 ou N2..." e nada é alterado.' }
    )

    Titulo 'Roteiro da demonstração'
    Write-Host '  Enter = próximo passo | r = recriar o banco e começar de novo | q = sair' -ForegroundColor DarkGray
    $i = 0
    while ($i -lt $passos.Count) {
        $p = $passos[$i]
        Write-Host ''
        Write-Host ("PASSO {0} de {1}   [{2}]" -f ($i + 1), $passos.Count, $p.Quem) -ForegroundColor White
        Write-Host ('  Faça:    ' + $p.Faca)
        Write-Host ('  Deve ver: ' + $p.Deve) -ForegroundColor Green
        $r = Read-Host '  >'
        if ($r -match '^[qQ]') { break }
        if ($r -match '^[rR]') {
            $script = (Join-Path $raiz 'database\SGA_completo.sql') -replace '\\', '/'
            & $mysql "-u$Usuario" "-h$Servidor" "-P$Porta" '--default-character-set=utf8mb4' -e "source $script" 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { Ok 'Banco recriado. Voltando ao passo 1.' } else { Falha 'Erro ao recriar o banco.' }
            $i = 0
            continue
        }
        $i++
    }
    Titulo 'Fim do ensaio. Para ensaiar de novo, rode o script outra vez (ele recria o banco).'
}
finally {
    # nada de senha sobrando no ambiente desta janela
    Remove-Item Env:\MYSQL_PWD -ErrorAction SilentlyContinue
    Remove-Item Env:\SGA_DB_PASSWORD -ErrorAction SilentlyContinue
    $senhaTexto = $null
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$RepoRoot = Split-Path -Parent $PSScriptRoot
$SuiteRoot = Join-Path $RepoRoot 'test_data\precision_validation_suite'
$ScanInputRoot = Join-Path $SuiteRoot 'scan_input'
$ExpectedRoot = Join-Path $SuiteRoot 'expected_results'

$Script:Random = [System.Random]::new(20260407)
$Script:UsedCpf = [System.Collections.Generic.HashSet[string]]::new()
$Script:UsedCnpj = [System.Collections.Generic.HashSet[string]]::new()
$Script:Manifest = [ordered]@{
    generatedAt = (Get-Date).ToString('s')
    selectedPatterns = @('CPF', 'CNPJ')
    files = [ordered]@{}
}

$FirstNames = @('Ana','Bruno','Carla','Daniel','Elisa','Fabio','Giovana','Hugo','Isabel','Joao','Karen','Lucas','Marina','Nicolas','Olivia','Paulo','Renata','Sergio','Talita','Vitor','Yasmin','Zeca')
$LastNames = @('Almeida','Barros','Cardoso','Duarte','Esteves','Ferreira','Gomes','Henrique','Junqueira','Lopes','Moraes','Novaes','Oliveira','Pereira','Queiroz','Ramos','Silva','Teixeira','Vasconcelos')
$Cities = @('Sao Paulo','Curitiba','Recife','Fortaleza','Goiania','Cuiaba','Campinas','Joinville','Maceio','Belem','Natal','Porto Alegre')
$CompanyPrefixes = @('Atlas','Boreal','Croma','Delta','Eixo','Futura','Grano','Horizonte','Inova','Jade','Kappa','Lumen','Matriz','Nexus','Orion','Prisma')
$CompanySuffixes = @('Tech','Holding','Servicos','Comercial','Logistica','Digital','Industria')

function Get-DigitsOnly {
    param([string]$Value)
    return ($Value -replace '\D', '')
}

function Test-RepeatedDigits {
    param([string]$Digits)
    if ([string]::IsNullOrEmpty($Digits)) { return $false }
    return (($Digits.ToCharArray() | Select-Object -Unique).Count -eq 1)
}

function Get-CheckDigit {
    param([int[]]$Digits, [int[]]$Weights)

    $sum = 0
    for ($index = 0; $index -lt $Digits.Count; $index++) {
        $sum += $Digits[$index] * $Weights[$index]
    }

    $remainder = $sum % 11
    if ($remainder -lt 2) { return 0 }
    return 11 - $remainder
}

function Test-Cpf {
    param([string]$Value)

    $digits = Get-DigitsOnly $Value
    if ($digits.Length -ne 11) { return $false }
    if (Test-RepeatedDigits $digits) { return $false }

    $numbers = @()
    foreach ($char in $digits.ToCharArray()) {
        $numbers += [int][string]$char
    }

    $first = Get-CheckDigit $numbers[0..8] @(10,9,8,7,6,5,4,3,2)
    $second = Get-CheckDigit ($numbers[0..8] + $first) @(11,10,9,8,7,6,5,4,3,2)
    return ($numbers[9] -eq $first -and $numbers[10] -eq $second)
}

function Test-Cnpj {
    param([string]$Value)

    $digits = Get-DigitsOnly $Value
    if ($digits.Length -ne 14) { return $false }
    if (Test-RepeatedDigits $digits) { return $false }

    $numbers = @()
    foreach ($char in $digits.ToCharArray()) {
        $numbers += [int][string]$char
    }

    $first = Get-CheckDigit $numbers[0..11] @(5,4,3,2,9,8,7,6,5,4,3,2)
    $second = Get-CheckDigit ($numbers[0..11] + $first) @(6,5,4,3,2,9,8,7,6,5,4,3,2)
    return ($numbers[12] -eq $first -and $numbers[13] -eq $second)
}

function Format-Cpf {
    param([string]$Digits)
    return '{0}.{1}.{2}-{3}' -f $Digits.Substring(0,3), $Digits.Substring(3,3), $Digits.Substring(6,3), $Digits.Substring(9,2)
}

function Format-Cnpj {
    param([string]$Digits)
    return '{0}.{1}.{2}/{3}-{4}' -f $Digits.Substring(0,2), $Digits.Substring(2,3), $Digits.Substring(5,3), $Digits.Substring(8,4), $Digits.Substring(12,2)
}

function New-RandomDigits {
    param([int]$Length)
    return ((1..$Length | ForEach-Object { $Script:Random.Next(0, 10) }) -join '')
}

function New-ValidCpf {
    param([bool]$Formatted)

    while ($true) {
        $base = @(1..9 | ForEach-Object { $Script:Random.Next(0, 10) })
        if (($base | Select-Object -Unique).Count -eq 1) { continue }

        $first = Get-CheckDigit $base @(10,9,8,7,6,5,4,3,2)
        $second = Get-CheckDigit ($base + $first) @(11,10,9,8,7,6,5,4,3,2)
        $digits = ($base + $first + $second) -join ''

        if ($Script:UsedCpf.Add($digits)) {
            if ($Formatted) { return Format-Cpf $digits }
            return $digits
        }
    }
}

function New-ValidCnpj {
    param([bool]$Formatted)

    while ($true) {
        $base = @(1..12 | ForEach-Object { $Script:Random.Next(0, 10) })
        if (($base | Select-Object -Unique).Count -eq 1) { continue }

        $first = Get-CheckDigit $base @(5,4,3,2,9,8,7,6,5,4,3,2)
        $second = Get-CheckDigit ($base + $first) @(6,5,4,3,2,9,8,7,6,5,4,3,2)
        $digits = ($base + $first + $second) -join ''

        if ($Script:UsedCnpj.Add($digits)) {
            if ($Formatted) { return Format-Cnpj $digits }
            return $digits
        }
    }
}

function New-InvalidCpf {
    while ($true) {
        $digits = New-RandomDigits 11
        if (-not (Test-Cpf $digits)) {
            if ($Script:Random.Next(0, 2) -eq 1) { return Format-Cpf $digits }
            return $digits
        }
    }
}

function New-InvalidCnpj {
    while ($true) {
        $digits = New-RandomDigits 14
        if (-not (Test-Cnpj $digits)) {
            if ($Script:Random.Next(0, 2) -eq 1) { return Format-Cnpj $digits }
            return $digits
        }
    }
}

function New-NoiseDecimal {
    param([string]$Value, [bool]$Negative)
    $digits = Get-DigitsOnly $Value
    $prefix = $Script:Random.Next(10, 99)
    $suffix = $Script:Random.Next(0, 999999).ToString('000000')
    if ($Negative) {
        return '-{0}.{1}{2}' -f $prefix, $digits, $suffix
    }
    return '{0}.{1}{2}' -f $prefix, $digits, $suffix
}

function New-RandomUpper {
    param([int]$Length)
    $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.ToCharArray()
    return (-join (1..$Length | ForEach-Object { $chars[$Script:Random.Next(0, $chars.Length)] }))
}

function New-RandomHex {
    param([int]$Length)
    $chars = '0123456789abcdef'.ToCharArray()
    return (-join (1..$Length | ForEach-Object { $chars[$Script:Random.Next(0, $chars.Length)] }))
}

function New-PersonName {
    return '{0} {1}' -f $FirstNames[$Script:Random.Next(0, $FirstNames.Count)], $LastNames[$Script:Random.Next(0, $LastNames.Count)]
}

function New-CompanyName {
    return '{0} {1}' -f $CompanyPrefixes[$Script:Random.Next(0, $CompanyPrefixes.Count)], $CompanySuffixes[$Script:Random.Next(0, $CompanySuffixes.Count)]
}

function New-City {
    return $Cities[$Script:Random.Next(0, $Cities.Count)]
}

function Escape-Xml {
    param([string]$Value)
    return $Value.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;').Replace("'", '&apos;')
}

function Escape-PdfText {
    param([string]$Value)
    return $Value.Replace('\', '\\').Replace('(', '\(').Replace(')', '\)')
}

function Ensure-Directory {
    param([string]$Path)
    [void](New-Item -ItemType Directory -Path $Path -Force)
}

function Write-Utf8File {
    param([string]$Path, [string]$Content)
    Ensure-Directory (Split-Path -Parent $Path)
    $utf8 = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function New-ZipXmlFile {
    param([string]$Path, [hashtable]$Entries)

    Ensure-Directory (Split-Path -Parent $Path)
    if (Test-Path $Path) { Remove-Item $Path -Force }

    $fileStream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Create)
    try {
        $archive = [System.IO.Compression.ZipArchive]::new($fileStream, [System.IO.Compression.ZipArchiveMode]::Create, $false)
        foreach ($entryName in $Entries.Keys) {
            $entry = $archive.CreateEntry($entryName)
            $stream = $entry.Open()
            try {
                $writer = [System.IO.StreamWriter]::new($stream, [System.Text.UTF8Encoding]::new($false))
                try {
                    $writer.Write($Entries[$entryName])
                }
                finally {
                    $writer.Dispose()
                }
            }
            finally {
                $stream.Dispose()
            }
        }
    }
    finally {
        if ($archive) { $archive.Dispose() }
        $fileStream.Dispose()
    }
}

function Build-DocxXml {
    param([string[]]$Paragraphs)
    $body = foreach ($paragraph in $Paragraphs) {
        '<w:p><w:r><w:t xml:space="preserve">{0}</w:t></w:r></w:p>' -f (Escape-Xml $paragraph)
    }
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>{0}</w:body></w:document>' -f (-join $body)
}

function Build-XlsxXml {
    param([object[][]]$Rows)
    $rowXml = New-Object System.Collections.Generic.List[string]
    for ($rowIndex = 0; $rowIndex -lt $Rows.Count; $rowIndex++) {
        $cells = New-Object System.Collections.Generic.List[string]
        for ($columnIndex = 0; $columnIndex -lt $Rows[$rowIndex].Count; $columnIndex++) {
            $cellRef = '{0}{1}' -f [char](65 + $columnIndex), ($rowIndex + 1)
            $cells.Add(('<c r="{0}" t="inlineStr"><is><t>{1}</t></is></c>' -f $cellRef, (Escape-Xml ([string]$Rows[$rowIndex][$columnIndex]))))
        }
        $rowXml.Add(('<row r="{0}">{1}</row>' -f ($rowIndex + 1), (-join $cells)))
    }
    return '<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>{0}</sheetData></worksheet>' -f (-join $rowXml)
}

function Build-PdfContent {
    param([string[]]$Lines)

    $builder = New-Object System.Text.StringBuilder
    [void]$builder.AppendLine('BT')
    [void]$builder.AppendLine('/F1 10 Tf')
    [void]$builder.AppendLine('40 780 Td')

    for ($index = 0; $index -lt $Lines.Count; $index++) {
        if ($index -gt 0) { [void]$builder.AppendLine('0 -14 Td') }
        [void]$builder.AppendLine(('({0}) Tj' -f (Escape-PdfText $Lines[$index])))
    }

    [void]$builder.AppendLine('ET')
    return $builder.ToString()
}

function New-SimplePdf {
    param([string]$Path, [string[]]$Lines)

    $content = Build-PdfContent $Lines
    $objects = @(
        '<< /Type /Catalog /Pages 2 0 R >>',
        '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
        ('<< /Length {0} >>' -f ([System.Text.Encoding]::ASCII.GetByteCount($content))) + "`nstream`n$content`nendstream",
        '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>'
    )

    $buffer = New-Object System.Text.StringBuilder
    [void]$buffer.Append("%PDF-1.4`n")
    $offsets = New-Object System.Collections.Generic.List[int]

    for ($index = 0; $index -lt $objects.Count; $index++) {
        $offsets.Add([System.Text.Encoding]::ASCII.GetByteCount($buffer.ToString()))
        [void]$buffer.AppendFormat('{0} 0 obj`n', $index + 1)
        [void]$buffer.Append($objects[$index])
        [void]$buffer.Append("`nendobj`n")
    }

    $xrefOffset = [System.Text.Encoding]::ASCII.GetByteCount($buffer.ToString())
    [void]$buffer.AppendFormat('xref`n0 {0}`n', $objects.Count + 1)
    [void]$buffer.Append('0000000000 65535 f `n')
    foreach ($offset in $offsets) {
        [void]$buffer.AppendFormat('{0} 00000 n `n', $offset.ToString('0000000000'))
    }
    [void]$buffer.AppendFormat('trailer`n<< /Root 1 0 R /Size {0} >>`n', $objects.Count + 1)
    [void]$buffer.AppendFormat('startxref`n{0}`n%%EOF', $xrefOffset)

    Ensure-Directory (Split-Path -Parent $Path)
    [System.IO.File]::WriteAllText($Path, $buffer.ToString(), [System.Text.Encoding]::ASCII)
}

function New-ManifestEntry {
    param([string]$RelativePath)
    $entry = [ordered]@{
        expectedCpfValues = New-Object System.Collections.Generic.List[string]
        expectedCnpjValues = New-Object System.Collections.Generic.List[string]
        invalidLookalikes = 0
    }
    $Script:Manifest.files[$RelativePath] = $entry
    return $entry
}

function Add-CpfExpected {
    param($Entry, [string]$Value)
    $Entry.expectedCpfValues.Add($Value) | Out-Null
}

function Add-CnpjExpected {
    param($Entry, [string]$Value)
    $Entry.expectedCnpjValues.Add($Value) | Out-Null
}

function Write-TextFixtures {
    $relativePath = 'text\01_clientes_validos.txt'
    $entry = New-ManifestEntry $relativePath
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('LOTE 01 - documentos validos em contexto realista') | Out-Null
    $lines.Add('Selecione apenas CPF e CNPJ no app para medir a precisao desta correcao.') | Out-Null
    $lines.Add('') | Out-Null

    foreach ($index in 1..18) {
        $cpf = New-ValidCpf ($index % 2 -eq 0)
        Add-CpfExpected $entry $cpf
        $lines.Add(('Cliente {0}: {1} | CPF: {2} | contrato: CTR-{3} | cidade: {4} | status: aprovado' -f $index, (New-PersonName), $cpf, (1000 + $index), (New-City))) | Out-Null
    }

    $lines.Add('') | Out-Null

    foreach ($index in 1..10) {
        $cnpj = New-ValidCnpj ($index % 2 -eq 0)
        Add-CnpjExpected $entry $cnpj
        $lines.Add(('Fornecedor {0}: {1} | CNPJ: {2} | unidade: {3} | observacao: integracao validada' -f $index, (New-CompanyName), $cnpj, (New-City))) | Out-Null
    }

    Write-Utf8File (Join-Path $ScanInputRoot $relativePath) (($lines -join "`n"))
}

function Write-NoiseFixture {
    $relativePath = 'noise\02_falsos_positivos_esperados.log'
    $entry = New-ManifestEntry $relativePath
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('ARQUIVO DE RUIDO - nenhum CPF/CNPJ deste arquivo deve ser detectado apos a correcao.') | Out-Null
    $lines.Add('Os exemplos abaixo simulam coordenadas, hashes, tokens, seriados e digitos invalidos.') | Out-Null
    $lines.Add('') | Out-Null

    foreach ($index in 0..179) {
        $invalidCpf = New-InvalidCpf
        $invalidCnpj = New-InvalidCnpj
        $coordA = New-NoiseDecimal $invalidCpf ($index % 2 -eq 0)
        $coordB = New-NoiseDecimal $invalidCpf (($index + 1) % 3 -eq 0)
        $token = '{0}{1}{2}' -f (New-RandomUpper 4), $invalidCpf, ($Script:Random.Next(0,999).ToString('000'))
        $serial = '{0}{1}{2}' -f (New-RandomHex 16), $invalidCnpj, (New-RandomHex 10)
        $cardLike = '{0}{1}' -f $invalidCpf, ($Script:Random.Next(0,99999).ToString('00000'))
        $lines.Add(('ruido_{0} lat={1} lon={2} token={3} serial={4} card_like={5}' -f $index.ToString('000'), $coordA, $coordB, $token, $serial, $cardLike)) | Out-Null
        $entry.invalidLookalikes += 5
    }

    foreach ($sample in @('111.111.111-11','22222222222','00.000.000/0000-00','11111111111111','123.456.789-10','12.345.678/9012-34')) {
        $lines.Add("sequencia_invalida=$sample") | Out-Null
        $entry.invalidLookalikes += 1
    }

    Write-Utf8File (Join-Path $ScanInputRoot $relativePath) (($lines -join "`n"))
}

function Write-CsvFixture {
    $relativePath = 'csv\03_lote_misto_clientes.csv'
    $entry = New-ManifestEntry $relativePath
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('tipo,nome,documento_principal,documento_secundario,status,observacao') | Out-Null

    foreach ($index in 1..14) {
        $cpf = New-ValidCpf ($index % 2 -eq 0)
        Add-CpfExpected $entry $cpf
        $lines.Add(('cliente,{0},{1},{2},ativo,registro verdadeiro' -f (New-PersonName), $cpf, (New-InvalidCpf))) | Out-Null
        $entry.invalidLookalikes += 1
    }

    foreach ($index in 1..8) {
        $cnpj = New-ValidCnpj ($index % 2 -eq 0)
        Add-CnpjExpected $entry $cnpj
        $lines.Add(('empresa,{0},{1},{2},ativo,registro verdadeiro' -f (New-CompanyName), $cnpj, (New-InvalidCnpj))) | Out-Null
        $entry.invalidLookalikes += 1
    }

    foreach ($index in 1..36) {
        $noiseToken = '{0}{1}{2}' -f (New-RandomUpper 4), (New-InvalidCpf), ($Script:Random.Next(0,999).ToString('000'))
        $lines.Add(('ruido,{0},{1},{2},pendente,{3}' -f (New-PersonName), (New-InvalidCpf), (New-InvalidCnpj), $noiseToken)) | Out-Null
        $entry.invalidLookalikes += 3
    }

    Write-Utf8File (Join-Path $ScanInputRoot $relativePath) (($lines -join "`n"))
}

function Write-JsonFixture {
    $relativePath = 'json\04_payloads_api.json'
    $entry = New-ManifestEntry $relativePath
    $payloads = New-Object System.Collections.Generic.List[object]

    foreach ($index in 1..10) {
        $cpf = New-ValidCpf ($index % 2 -eq 0)
        Add-CpfExpected $entry $cpf
        $payloads.Add([ordered]@{
            event = 'customer_sync'
            requestId = (New-RandomHex 24)
            customer = [ordered]@{
                name = (New-PersonName)
                cpf = $cpf
                city = (New-City)
            }
            noise = [ordered]@{
                token = ('{0}{1}{2}' -f (New-RandomUpper 3), (New-InvalidCpf), ($Script:Random.Next(0,9999).ToString('0000')))
                hash = (New-RandomHex 40)
            }
        }) | Out-Null
        $entry.invalidLookalikes += 1
    }

    foreach ($index in 1..8) {
        $cnpj = New-ValidCnpj ($index % 2 -eq 0)
        Add-CnpjExpected $entry $cnpj
        $payloads.Add([ordered]@{
            event = 'supplier_sync'
            requestId = (New-RandomHex 24)
            supplier = [ordered]@{
                companyName = (New-CompanyName)
                cnpj = $cnpj
                city = (New-City)
            }
            noise = [ordered]@{
                serial = ('{0}{1}{2}' -f (New-RandomHex 8), (New-InvalidCnpj), (New-RandomHex 8))
                position = (New-NoiseDecimal (New-InvalidCpf) $true)
            }
        }) | Out-Null
        $entry.invalidLookalikes += 2
    }

    foreach ($index in 1..18) {
        $payloads.Add([ordered]@{
            event = 'noise_payload'
            requestId = (New-RandomHex 24)
            metrics = [ordered]@{
                lat = (New-NoiseDecimal (New-InvalidCpf) ($index % 2 -eq 0))
                lon = (New-NoiseDecimal (New-InvalidCpf) ($index % 3 -eq 0))
                series = ('{0}{1}{2}' -f (New-RandomUpper 4), (New-InvalidCpf), ($Script:Random.Next(0,999).ToString('000')))
                orgId = ('{0}{1}' -f (New-InvalidCnpj), ($Script:Random.Next(0,9999).ToString('0000')))
            }
        }) | Out-Null
        $entry.invalidLookalikes += 4
    }

    $json = $payloads | ConvertTo-Json -Depth 6
    Write-Utf8File (Join-Path $ScanInputRoot $relativePath) $json
}

function Write-MarkdownFixture {
    $relativePath = 'markdown\05_documentacao_operacional.md'
    $entry = New-ManifestEntry $relativePath
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# Documentacao operacional de homologacao') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('Este arquivo mistura exemplos verdadeiros e ruidos que antes geravam falso positivo.') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## Casos que DEVEM ser encontrados') | Out-Null
    $lines.Add('') | Out-Null

    foreach ($index in 1..8) {
        $cpf = New-ValidCpf ($index % 2 -eq 0)
        Add-CpfExpected $entry $cpf
        $lines.Add(('- Responsavel {0}: {1} com CPF {2} no dossie de aprovacao.' -f $index, (New-PersonName), $cpf)) | Out-Null
    }

    foreach ($index in 1..6) {
        $cnpj = New-ValidCnpj ($index % 2 -eq 0)
        Add-CnpjExpected $entry $cnpj
        $lines.Add(('- Empresa parceira {0}: {1} com CNPJ {2}.' -f $index, (New-CompanyName), $cnpj)) | Out-Null
    }

    $lines.Add('') | Out-Null
    $lines.Add('## Casos que NAO devem ser encontrados') | Out-Null
    $lines.Add('') | Out-Null

    foreach ($index in 1..30) {
        $lines.Add(('- Ruido {0}: lat={1} token={2} serie={3}' -f $index, (New-NoiseDecimal (New-InvalidCpf) ($index % 2 -eq 0)), ('{0}{1}{2}' -f (New-RandomUpper 4), (New-InvalidCpf), ($Script:Random.Next(0,999).ToString('000'))), ('{0}{1}' -f (New-InvalidCnpj), ($Script:Random.Next(0,99).ToString('00'))))) | Out-Null
        $entry.invalidLookalikes += 3
    }

    Write-Utf8File (Join-Path $ScanInputRoot $relativePath) (($lines -join "`n"))
}

function Write-NestedFixture {
    $relativePath = 'subpastas\lote_secundario.txt'
    $entry = New-ManifestEntry $relativePath
    $lines = New-Object System.Collections.Generic.List[string]

    foreach ($index in 1..10) {
        $cpf = New-ValidCpf ($index % 2 -eq 1)
        Add-CpfExpected $entry $cpf
        $lines.Add(('Registro secundario {0} -> CPF confirmado: {1} | analista: {2}' -f $index, $cpf, (New-PersonName))) | Out-Null
    }

    foreach ($index in 1..6) {
        $cnpj = New-ValidCnpj ($index % 2 -eq 1)
        Add-CnpjExpected $entry $cnpj
        $lines.Add(('Parceiro secundario {0} -> CNPJ confirmado: {1} | regional: {2}' -f $index, $cnpj, (New-City))) | Out-Null
    }

    foreach ($index in 1..40) {
        $lines.Add(('Ruido secundario {0}: lote={1}{2}{3} geo={4}' -f $index, (New-RandomHex 10), (New-InvalidCpf), (New-RandomHex 4), (New-NoiseDecimal (New-InvalidCpf) ($index % 2 -eq 0)))) | Out-Null
        $entry.invalidLookalikes += 2
    }

    Write-Utf8File (Join-Path $ScanInputRoot $relativePath) (($lines -join "`n"))
}

function Write-DocxFixture {
    $relativePath = 'office\06_dossie_cliente.docx'
    $entry = New-ManifestEntry $relativePath
    $paragraphs = New-Object System.Collections.Generic.List[string]
    $paragraphs.Add('Dossie do cliente - arquivo DOCX de homologacao.') | Out-Null

    foreach ($index in 1..8) {
        $cpf = New-ValidCpf ($index % 2 -eq 0)
        Add-CpfExpected $entry $cpf
        $paragraphs.Add(('Responsavel {0}: {1} / CPF {2} / unidade {3}' -f $index, (New-PersonName), $cpf, (New-City))) | Out-Null
    }

    foreach ($index in 1..6) {
        $cnpj = New-ValidCnpj ($index % 2 -eq 0)
        Add-CnpjExpected $entry $cnpj
        $paragraphs.Add(('Empresa {0}: {1} / CNPJ {2} / status homologado' -f $index, (New-CompanyName), $cnpj)) | Out-Null
    }

    foreach ($index in 1..24) {
        $paragraphs.Add(('Ruido DOCX {0}: ref={1}{2}{3} coord={4} serial={5}{6}' -f $index, (New-RandomUpper 4), (New-InvalidCpf), ($Script:Random.Next(0,999).ToString('000')), (New-NoiseDecimal (New-InvalidCpf) ($index % 2 -eq 0)), (New-InvalidCnpj), ($Script:Random.Next(0,99).ToString('00')))) | Out-Null
        $entry.invalidLookalikes += 3
    }

    $docXml = Build-DocxXml $paragraphs
    New-ZipXmlFile (Join-Path $ScanInputRoot $relativePath) @{ 'word/document.xml' = $docXml }
}

function Write-XlsxFixture {
    $relativePath = 'office\07_planilha_operacoes.xlsx'
    $entry = New-ManifestEntry $relativePath
    $rows = New-Object System.Collections.Generic.List[object[]]
    $rows.Add(@('tipo','nome','documento','cidade','observacao')) | Out-Null

    foreach ($index in 1..14) {
        $cpf = New-ValidCpf ($index % 2 -eq 0)
        Add-CpfExpected $entry $cpf
        $rows.Add(@('cliente', (New-PersonName), $cpf, (New-City), 'positivo')) | Out-Null
    }

    foreach ($index in 1..10) {
        $cnpj = New-ValidCnpj ($index % 2 -eq 0)
        Add-CnpjExpected $entry $cnpj
        $rows.Add(@('empresa', (New-CompanyName), $cnpj, (New-City), 'positivo')) | Out-Null
    }

    foreach ($index in 1..44) {
        $rows.Add(@('ruido', (New-CompanyName), ('{0}{1}{2}' -f (New-RandomUpper 4), (New-InvalidCpf), ($Script:Random.Next(0,999).ToString('000'))), (New-City), (New-NoiseDecimal (New-InvalidCpf) ($index % 2 -eq 0)))) | Out-Null
        $entry.invalidLookalikes += 2
    }

    $sheetXml = Build-XlsxXml $rows
    New-ZipXmlFile (Join-Path $ScanInputRoot $relativePath) @{ 'xl/worksheets/sheet1.xml' = $sheetXml }
}

function Write-PdfFixture {
    $relativePath = 'docs\08_relatorio_comprovantes.pdf'
    $entry = New-ManifestEntry $relativePath
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('Relatorio PDF de comprovantes e anexos.') | Out-Null

    foreach ($index in 1..6) {
        $cpf = New-ValidCpf $true
        Add-CpfExpected $entry $cpf
        $lines.Add(('Comprovante {0}: {1} CPF {2} aprovado.' -f $index, (New-PersonName), $cpf)) | Out-Null
    }

    foreach ($index in 1..5) {
        $cnpj = New-ValidCnpj $true
        Add-CnpjExpected $entry $cnpj
        $lines.Add(('Fornecedor {0}: {1} CNPJ {2} confirmado.' -f $index, (New-CompanyName), $cnpj)) | Out-Null
    }

    foreach ($index in 1..18) {
        $lines.Add(('Ruido PDF {0}: geo {1} / token {2}{3}{4} / serie {5}{6}' -f $index, (New-NoiseDecimal (New-InvalidCpf) ($index % 2 -eq 0)), (New-RandomUpper 4), (New-InvalidCpf), ($Script:Random.Next(0,999).ToString('000')), (New-InvalidCnpj), ($Script:Random.Next(0,90).ToString('00')))) | Out-Null
        $entry.invalidLookalikes += 3
    }

    New-SimplePdf (Join-Path $ScanInputRoot $relativePath) $lines
}

function Write-ExpectedResults {
    $summary = [ordered]@{
        generatedAt = (Get-Date).ToString('s')
        note = 'Escaneie apenas a pasta scan_input com os padroes CPF e CNPJ habilitados.'
        totalExpectedCpf = 0
        totalExpectedCnpj = 0
        totalInvalidLookalikes = 0
        files = [ordered]@{}
    }

    foreach ($fileName in $Script:Manifest.files.Keys) {
        $fileEntry = $Script:Manifest.files[$fileName]
        $summary.totalExpectedCpf += $fileEntry.expectedCpfValues.Count
        $summary.totalExpectedCnpj += $fileEntry.expectedCnpjValues.Count
        $summary.totalInvalidLookalikes += $fileEntry.invalidLookalikes
        $summary.files[$fileName] = [ordered]@{
            expectedCpfCount = $fileEntry.expectedCpfValues.Count
            expectedCnpjCount = $fileEntry.expectedCnpjValues.Count
            invalidLookalikes = $fileEntry.invalidLookalikes
            expectedCpfValues = @($fileEntry.expectedCpfValues)
            expectedCnpjValues = @($fileEntry.expectedCnpjValues)
        }
    }

    $summary.totalExpectedFindings = $summary.totalExpectedCpf + $summary.totalExpectedCnpj

    $json = $summary | ConvertTo-Json -Depth 7
    Write-Utf8File (Join-Path $ExpectedRoot 'manifest.json') $json

    $readme = @"
# Suite de precisao para CPF e CNPJ

Escaneie a pasta `scan_input` com apenas os padroes `CPF` e `CNPJ` selecionados.

Resumo esperado:
- Total esperado de CPF: $($summary.totalExpectedCpf)
- Total esperado de CNPJ: $($summary.totalExpectedCnpj)
- Total esperado de achados: $($summary.totalExpectedFindings)
- Total de lookalikes invalidos: $($summary.totalInvalidLookalikes)

Arquivos gerados para scan:
- text\01_clientes_validos.txt
- noise\02_falsos_positivos_esperados.log
- csv\03_lote_misto_clientes.csv
- json\04_payloads_api.json
- markdown\05_documentacao_operacional.md
- subpastas\lote_secundario.txt
- office\06_dossie_cliente.docx
- office\07_planilha_operacoes.xlsx
- docs\08_relatorio_comprovantes.pdf

Use o arquivo `manifest.json` para comparar o resultado real do app com o esperado.
"@

    Write-Utf8File (Join-Path $ExpectedRoot 'README.md') $readme.Trim()
}

if (Test-Path $SuiteRoot) {
    Remove-Item $SuiteRoot -Recurse -Force
}

Ensure-Directory $ScanInputRoot
Ensure-Directory $ExpectedRoot

Write-TextFixtures
Write-NoiseFixture
Write-CsvFixture
Write-JsonFixture
Write-MarkdownFixture
Write-NestedFixture
Write-DocxFixture
Write-XlsxFixture
Write-PdfFixture
Write-ExpectedResults

Write-Host "Suite criada em: $SuiteRoot"
Write-Host "Pasta para escanear: $ScanInputRoot"
Write-Host "Manifesto esperado: $(Join-Path $ExpectedRoot 'manifest.json')"
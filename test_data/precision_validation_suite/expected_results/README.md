# Suite de precisao para CPF e CNPJ

Escaneie a pasta scan_input com apenas os padroes CPF e CNPJ selecionados.

Resumo esperado:
- Total esperado de CPF: 88
- Total esperado de CNPJ: 59
- Total esperado de achados: 147
- Total de lookalikes invalidos: 1518

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

Use o arquivo manifest.json para comparar o resultado real do app com o esperado.
import markdown
import subprocess
import os
import tempfile

MD_FILE  = "FLUTTER_GUIA.md"
PDF_FILE = "FLUTTER_GUIA.pdf"
EDGE     = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

CSS = """
* { box-sizing: border-box; margin: 0; padding: 0; }
body {
    font-family: 'Segoe UI', sans-serif;
    font-size: 14px;
    line-height: 1.7;
    color: #1a1a1a;
    max-width: 860px;
    margin: 0 auto;
    padding: 48px 56px;
}
h1 { font-size: 28px; color: #c0392b; margin: 0 0 8px; padding-bottom: 10px;
     border-bottom: 3px solid #c0392b; }
h2 { font-size: 20px; color: #c0392b; margin: 36px 0 12px;
     padding-bottom: 6px; border-bottom: 1px solid #f0c0bb; }
h3 { font-size: 16px; color: #333; margin: 24px 0 8px; }
p  { margin: 10px 0; }
a  { color: #c0392b; text-decoration: none; }

/* blocos de código */
pre {
    background: #1e1e2e;
    color: #cdd6f4;
    border-radius: 8px;
    padding: 16px 20px;
    overflow-x: auto;
    margin: 14px 0;
    font-size: 12.5px;
    line-height: 1.6;
}
code {
    font-family: 'Cascadia Code', 'Consolas', monospace;
    font-size: 12.5px;
}
p code, li code, td code {
    background: #f0f0f0;
    border-radius: 4px;
    padding: 1px 5px;
    color: #c0392b;
}
pre code { background: none; color: inherit; padding: 0; }

/* tabelas */
table {
    border-collapse: collapse;
    width: 100%;
    margin: 16px 0;
    font-size: 13px;
}
th {
    background: #c0392b;
    color: white;
    padding: 8px 12px;
    text-align: left;
}
td { padding: 7px 12px; border-bottom: 1px solid #eee; }
tr:nth-child(even) td { background: #fafafa; }

/* listas */
ul, ol { padding-left: 24px; margin: 10px 0; }
li { margin: 4px 0; }

/* blockquote */
blockquote {
    border-left: 4px solid #c0392b;
    background: #fff5f5;
    padding: 10px 16px;
    margin: 14px 0;
    border-radius: 0 6px 6px 0;
    color: #555;
}

/* separadores */
hr { border: none; border-top: 1px solid #eee; margin: 32px 0; }

/* quebra de página para PDF */
h2 { page-break-before: auto; }

/* cabeçalho da primeira página */
.doc-header {
    background: linear-gradient(135deg, #c0392b, #7b0000);
    color: white;
    padding: 32px 40px;
    border-radius: 10px;
    margin-bottom: 36px;
}
.doc-header h1 { color: white; border: none; font-size: 26px; }
.doc-header p  { color: rgba(255,255,255,0.8); margin: 6px 0 0; font-size: 14px; }
"""

def build_html(md_text: str) -> str:
    body = markdown.markdown(
        md_text,
        extensions=["tables", "fenced_code", "toc", "nl2br"]
    )
    # Transforma o primeiro <h1> em um bloco de cabeçalho destacado
    body = body.replace(
        "<h1>Guia Flutter",
        '<div class="doc-header"><h1>Guia Flutter',
        1,
    )
    # fecha a div depois do primeiro <p> após o h1
    body = body.replace("</p>\n<hr>", "</p></div>\n<hr>", 1)

    return f"""<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<style>{CSS}</style>
</head>
<body>
{body}
</body>
</html>"""


def main():
    with open(MD_FILE, encoding="utf-8") as f:
        md_text = f.read()

    html = build_html(md_text)

    # Salva o HTML num arquivo temporário
    with tempfile.NamedTemporaryFile(
        suffix=".html", delete=False, mode="w", encoding="utf-8"
    ) as tmp:
        tmp.write(html)
        tmp_path = tmp.name

    pdf_abs = os.path.abspath(PDF_FILE)
    file_url = "file:///" + tmp_path.replace("\\", "/")

    print(f"Convertendo {MD_FILE} -> {PDF_FILE} ...")
    result = subprocess.run(
        [
            EDGE,
            "--headless=new",
            "--disable-gpu",
            "--no-sandbox",
            "--run-all-compositor-stages-before-draw",
            f"--print-to-pdf={pdf_abs}",
            file_url,
        ],
        capture_output=True,
        text=True,
        timeout=30,
    )

    os.unlink(tmp_path)

    if os.path.exists(pdf_abs):
        size_kb = os.path.getsize(pdf_abs) // 1024
        print(f"PDF gerado: {pdf_abs}  ({size_kb} KB)")
    else:
        print("Falha ao gerar PDF.")
        print(result.stderr)


if __name__ == "__main__":
    main()

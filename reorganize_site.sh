#!/usr/bin/env bash
set -euo pipefail

# >>> EDIT THESE TWO LINES <<<
SRC_ROOT="/Users/adrienallorant/Documents/Jeanne_Jozon"     # folder that contains Atelier, Biographie, Production, etc.
SITE_ROOT="/Users/adrienallorant/Documents/hugo_site_jj"    # your Hugo site root (has config.yaml)
# You may also run:  SRC_ROOT="/path/Jeanne_Jozon" SITE_ROOT="$(pwd)" ./reorganize_site.sh

# Accept positional overrides (optional)
[ "${1-}" != "" ] && SRC_ROOT="$1"
[ "${2-}" != "" ] && SITE_ROOT="$2"

echo "SRC_ROOT: $SRC_ROOT"
echo "SITE_ROOT: $SITE_ROOT"
[ -d "$SRC_ROOT" ] || { echo "ERROR: SRC_ROOT not found"; exit 1; }
[ -d "$SITE_ROOT" ] || { echo "ERROR: SITE_ROOT not found"; exit 1; }

cd "$SITE_ROOT"

echo "==> 1) Create sections"
mkdir -p content/{atelier,biographie,portrait,production,appartement-babylone,salons,scenes-rurales}
mkdir -p content/production/{bijoux,dessins,ebauches,jouets,pastel-craie,pyrogravure,sculpture,vases-buires-encriers-salieres}
mkdir -p assets/css/extended static/images

echo "==> 2) Copy & normalize images (lowercase, hyphens, strip accents)"
python3 - "$SRC_ROOT" "$SITE_ROOT" <<'PY'
import os, shutil, re, json, sys
from pathlib import Path
try:
    from unidecode import unidecode
except ImportError:
    print("Missing 'unidecode'. Activate your venv then:  python -m pip install unidecode", file=sys.stderr); sys.exit(1)

SRC_ROOT = Path(sys.argv[1]); SITE_ROOT = Path(sys.argv[2])
dest = SITE_ROOT / "static" / "images"
dest.mkdir(parents=True, exist_ok=True)

maps = {
    "atelier": ["Atelier"],
    "portrait": ["Portrait"],
    "appartement-babylone": ["rue de Babylone"],
    "scenes-rurales": ["Scène rurale", "Scène rurale"],
    "production/bijoux": ["Production/Bijoux"],
    "production/dessins": ["Production/Dessins"],
    "production/ebauches": ["Production/Ebauches"],
    "production/jouets": ["Production/Jouets"],
    "production/pastel-craie": ["Production/Pastel et craie"],
    "production/pyrogravure": ["Production/Pyrogravure"],
    "production/sculpture": ["Production/Sculpture"],
    "production/vases-buires-encriers-salieres": ["Production/Vase, buire,encrier, salière","Production/Vase, buire,encrier, salière"],
}

def websafe(name:str)->str:
    s = unidecode(name).lower()
    s = re.sub(r"[^\w\s.-]", "", s).replace(" ", "-")
    s = re.sub(r"-+", "-", s)
    return s

manifest = {}
for section, folders in maps.items():
    outdir = dest / section
    outdir.mkdir(parents=True, exist_ok=True)
    manifest[section] = []
    for rel in folders:
        srcdir = SRC_ROOT / rel
        if not srcdir.exists(): continue
        for root, _, files in os.walk(srcdir):
            for f in files:
                if not re.search(r"\.(jpe?g|png|tif|tiff|webp)$", f, re.I): continue
                src = Path(root)/f
                new = websafe(f)
                target = outdir/new
                i = 2
                while target.exists():
                    stem, ext = os.path.splitext(new)
                    target = outdir/f"{stem}-{i}{ext}"; i+=1
                shutil.copy2(src, target)
                manifest[section].append(str(target.relative_to(dest)))

mf = dest/"manifest.json"
mf.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
print(f"Wrote manifest with {sum(len(v) for v in manifest.values())} images ->", mf)
PY

echo "==> 3) Generate section _index.md and galleries"
python3 - "$SITE_ROOT" <<'PY'
import json, os, sys
from pathlib import Path
SITE_ROOT = Path(sys.argv[1])
mf = json.loads((SITE_ROOT/"static/images/manifest.json").read_text(encoding="utf-8"))

def write(p:Path, txt:str):
    p.parent.mkdir(parents=True, exist_ok=True); p.write_text(txt, encoding="utf-8")

def cover(section):
    imgs = mf.get(section, [])
    return ("/images/"+imgs[0]) if imgs else None

def gallery(section):
    imgs = mf.get(section, [])
    if not imgs: return "\n*(Aucune image importée pour le moment.)*\n"
    lines = ['<div class="gallery">']
    for rel in imgs:
        url = "/images/"+rel
        lines.append(f'  <a href="{url}" target="_blank" rel="noopener"><img loading="lazy" src="{url}" alt=""></a>')
    lines.append("</div>")
    return "\n".join(lines)+"\n"

sections = {
 "atelier": {"title":"Atelier","summary":"Photographies d’atelier"},
 "biographie": {"title":"Biographie","summary":"Parcours & chronologie"},
 "portrait": {"title":"Portrait","summary":"Autoportraits et portraits"},
 "production": {"title":"Production","summary":"Œuvres par techniques et genres"},
 "production/bijoux":{"title":"Bijoux","summary":"Créations et bijoux d’art"},
 "production/dessins":{"title":"Dessins","summary":"Croquis, portraits, scènes"},
 "production/ebauches":{"title":"Ébauches","summary":"Études et volumes préparatoires"},
 "production/jouets":{"title":"Jouets","summary":"Figurines et scènes"},
 "production/pastel-craie":{"title":"Pastel & craie","summary":"Paysages, fleurs, scènes"},
 "production/pyrogravure":{"title":"Pyrogravure","summary":"Décors et motifs"},
 "production/sculpture":{"title":"Sculpture","summary":"Bustes, bas-reliefs, figures"},
 "production/vases-buires-encriers-salieres":{"title":"Vases, buires, encriers, salières","summary":"Objets d’art décoratif"},
 "appartement-babylone":{"title":"Appartement rue de Babylone","summary":"Photographies du lieu et de la famille"},
 "salons":{"title":"Salons","summary":"Participations et expositions"},
 "scenes-rurales":{"title":"Scènes rurales","summary":"Photographies et études"},
}

photo_sections = [s for s in sections if not s.endswith("biographie") and not s.endswith("salons") and s!="production"]

# write section pages
for s, meta in sections.items():
    p = SITE_ROOT/"content"/s/"_index.md"
    fm = ["---", f'title: "{meta["title"]}"', f'summary: "{meta["summary"]}"']
    cv = cover(s)
    if cv: fm += ["cover:", f"  image: \"{cv}\"", f'  alt: "{meta["title"]}"']
    fm += ["---",""]
    body = gallery(s) if s in photo_sections else ""
    write(p, "\n".join(fm)+body)

# production landing gets links to sub-sections
subs = [
 ("Bijoux","/production/bijoux/"),
 ("Dessins","/production/dessins/"),
 ("Ébauches","/production/ebauches/"),
 ("Jouets","/production/jouets/"),
 ("Pastel & craie","/production/pastel-craie/"),
 ("Pyrogravure","/production/pyrogravure/"),
 ("Sculpture","/production/sculpture/"),
 ("Vases, buires, encriers, salières","/production/vases-buires-encriers-salieres/"),
]
links = "\n".join([f"- [{t}]({u})" for t,u in subs])
prod = SITE_ROOT/"content/production/_index.md"
base = prod.read_text(encoding="utf-8") if prod.exists() else "---\ntitle: \"Production\"\n---\n"
base += "\n## Parcours par techniques\n\n" + links + "\n"
prod.write_text(base, encoding="utf-8")

# CSS for gallery grid
css = SITE_ROOT/"assets/css/extended/custom.css"
extra = """
.gallery{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:12px;margin:12px 0}
.gallery img{width:100%;height:220px;object-fit:cover;border-radius:14px}
"""
existing = css.read_text(encoding="utf-8") if css.exists() else ""
if ".gallery{" not in existing: css.write_text(existing+extra, encoding="utf-8")
PY

echo "==> 4) Excel -> Markdown tables (Chronologie / Production / Salons)"
python3 - "$SRC_ROOT" "$SITE_ROOT" <<'PY'
import sys, pandas as pd
from pathlib import Path

SRC_ROOT = Path(sys.argv[1]); SITE_ROOT = Path(sys.argv[2])

def xl_to_md(path:Path):
    try:
        xls = pd.ExcelFile(path)
    except Exception as e:
        return f"\n*Impossible de lire {path.name}: {e}*\n"
    out=[]
    for sheet in xls.sheet_names:
        try:
            df = xls.parse(sheet)
            if df.empty: continue
            out.append(f"\n### {sheet}\n\n"+df.to_markdown(index=False))
        except Exception as e:
            out.append(f"\n*Feuille {sheet}: erreur {e}*\n")
    return "\n".join(out) if out else "\n*(Aucune donnée trouvée)*\n"

# Biographie: Chronologie.xls (found under Production folder per your tree)
chrono = SRC_ROOT/"Production"/"Chronologie.xls"
if chrono.exists():
    md = xl_to_md(chrono)
    p = SITE_ROOT/"content/biographie/_index.md"
    base = p.read_text(encoding="utf-8")
    base += "\n\n## Chronologie\n"+md+"\n"
    p.write_text(base, encoding="utf-8")

# Production.xls -> Production landing
prod = SRC_ROOT/"Production"/"Production.xls"
if prod.exists():
    md = xl_to_md(prod)
    p = SITE_ROOT/"content/production/_index.md"
    base = p.read_text(encoding="utf-8")
    base += "\n\n## Tableau de production\n"+md+"\n"
    p.write_text(base, encoding="utf-8")

# Salons.xls -> Salons page
salons = SRC_ROOT/"Salons.xls"
if salons.exists():
    md = xl_to_md(salons)
    p = SITE_ROOT/"content/salons/_index.md"
    base = p.read_text(encoding="utf-8")
    base += "\n\n## Tableau des salons et expositions\n"+md+"\n"
    p.write_text(base, encoding="utf-8")
PY

echo "==> 5) Word (.docx) -> Markdown (append to Salons)"
SALON_DOC="$SRC_ROOT/Salons/Participation de Jeanne Jozon aux expositions artistiques.docx"
if [ -f "$SALON_DOC" ]; then
  mkdir -p content/salons
  if command -v pandoc >/dev/null 2>&1; then
    pandoc "$SALON_DOC" -t gfm -o /tmp/salons_doc.md
    printf "\n## Texte (document)\n\n" >> content/salons/_index.md
    cat /tmp/salons_doc.md >> content/salons/_index.md
  elif command -v textutil >/dev/null 2>&1; then
    textutil -convert txt -output /tmp/salons_doc.txt "$SALON_DOC"
    printf "\n## Texte (document)\n\n" >> content/salons/_index.md
    cat /tmp/salons_doc.txt >> content/salons/_index.md
  else
    echo "NOTE: Neither pandoc nor textutil found; skipping .docx extraction (install pandoc with 'brew install pandoc')."
  fi
fi

echo "==> 6) Write menu snippet to merge into config.yaml (manual paste)"
cat > _menu_new.yaml <<'YML'
menu:
  main:
    - name: Atelier
      url: /atelier/
      weight: 1
    - name: Biographie
      url: /biographie/
      weight: 2
    - name: Portrait
      url: /portrait/
      weight: 3
    - name: Production
      url: /production/
      weight: 4
    - name: Appartement rue de Babylone
      url: /appartement-babylone/
      weight: 5
    - name: Salons
      url: /salons/
      weight: 6
    - name: Scènes rurales
      url: /scenes-rurales/
      weight: 7
    - name: Contact
      url: /contact/
      weight: 8
YML
echo "Wrote menu snippet at: $SITE_ROOT/_menu_new.yaml"
echo "Open config.yaml and replace your 'menu:' section with the contents of _menu_new.yaml."

echo "==> 7) ZIP the updated site"
cd "$SITE_ROOT/.."
zip -rq "hugo_site_jj_reorganized.zip" "$(basename "$SITE_ROOT")"
echo "✓ ZIP created at: $(pwd)/hugo_site_jj_reorganized.zip"

echo
echo "All done."
echo "Now run:"
echo "  cd \"$SITE_ROOT\""
echo "  hugo serve -D -b http://localhost:1313/ --ignoreCache --disableFastRender"


import hcl2
import argparse
import re

COMMENT_HEADER_REGEX = r'###\s*(.*?)\s*#*\s*variable\s*"(.*)"'

parser = argparse.ArgumentParser("Converts a variables.tf file to an asciidoc description list. Treats comment blocks starting with ### as section headers")
parser.add_argument("variables_tf")
args = parser.parse_args()

with open(args.variables_tf, 'r') as f:
    d = hcl2.load(f)
    f.seek(0)
    text = '\n'.join(f.readlines())
    category_matches = re.findall(COMMENT_HEADER_REGEX, text, flags=re.MULTILINE)
    first_var_to_cat = { m[1]: m[0] for m in category_matches }

for v in d['variable']:
    name = list(v.keys())[0]
    if name in first_var_to_cat:
        print(f"{first_var_to_cat[name].title()}::")
    t = v[name]['type'].strip("{}$")
    if t.startswith("object"):
        t = "object"
    default = f"[default={v[name]['default']}]" if "default" in v[name] else ""
    desc = v[name]["description"]
    print(f"`{name}` ({t}) {default}::: {desc.strip()}")
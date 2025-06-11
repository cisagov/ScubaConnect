import hcl2
import argparse

parser = argparse.ArgumentParser("Converts variables in a .tf file to asciidoc description list")
parser.add_argument("variables_tf")
args = parser.parse_args()


with open(args.variables_tf, 'r') as f:
    d = hcl2.load(f)

for v in d['variable']:
    name = list(v.keys())[0]
    t = v[name]['type'].strip("{}$")
    if t.startswith("object"):
        t = "object"
    default = f"[default={v[name]['default']}]" if "default" in v[name] else ""
    desc = v[name]["description"]
    print(f"`{name}` ({t}) {default}::: {desc.strip()}")
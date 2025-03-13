import hcl2

with open('m365/terraform/variables.tf', 'r') as f:
    d = hcl2.load(f)

for v in d['variable']:
    # print(v)
    name = list(v.keys())[0]
    t = v[name]['type'].strip("{}$")
    if t.startswith("object"):
        t = "object"
    default = f"[default={v[name]['default']}]" if "default" in v[name] else ""
    desc = v[name]["description"]
    print(f"`{name}` ({t}) {default}::: {desc}")
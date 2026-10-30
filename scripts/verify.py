"""Compare every serialized property and instance reference, ignoring generated referent labels."""
import xml.etree.ElementTree as ET
from pathlib import Path

def canonical(path):
    root = ET.parse(path).getroot()
    refs = {item.attrib['referent']: str(i) for i, item in enumerate(root.iter('Item'))}
    def visit(node):
        attrs = dict(node.attrib)
        if 'referent' in attrs:
            attrs['referent'] = refs[attrs['referent']]
        text = node.text or ''
        if node.tag == 'Ref':
            text = refs.get(text, text)
        children = [visit(child) for child in node]
        if node.tag == 'Properties':
            children.sort(key=repr)
        if children and not text.strip():
            text = ''
        return (node.tag, tuple(sorted(attrs.items())), text, tuple(children))
    return visit(root)

for left, right in [('before', 'after'), ('original', 'source-reset')]:
    a, b = canonical(f'build/{left}.rbxlx'), canonical(f'build/{right}.rbxlx')
    if a != b:
        Path('build/difference.txt').write_text(f'{left}: {a!r}\n{right}: {b!r}')
        raise AssertionError(f'Property/reference difference: {left} vs {right}')
print('All instances, properties, and references preserved')

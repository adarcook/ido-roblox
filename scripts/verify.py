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
        numeric = node.tag in {'float', 'double', 'X', 'Y', 'Z', 'R', 'G', 'B', 'Scale', 'Offset'} or (node.tag.startswith('R') and node.tag[1:].isdigit())
        if numeric and not len(node):
            try:
                text = str(round(float(text), 6))
            except ValueError:
                pass
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
        def difference(x, y, path='root'):
            if type(x) != type(y) or not isinstance(x, tuple):
                if x != y:
                    print('Difference at', path, repr(x)[:300], repr(y)[:300])
                    return True
                return False
            if len(x) != len(y):
                print('Length difference at', path, len(x), len(y))
                return True
            for i, (xx, yy) in enumerate(zip(x, y)):
                if xx != yy and difference(xx, yy, path + '/' + str(i)):
                    return True
            return False
        difference(a, b)
        Path('build/difference.txt').write_text(f'{left}: {a!r}\n{right}: {b!r}')
        raise AssertionError(f'Property/reference difference: {left} vs {right}')
print('All instances, properties, and references preserved')

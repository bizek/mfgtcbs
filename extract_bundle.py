import zipfile, io, os, re

outer = zipfile.ZipFile('E:/Projects/extraction-survivors/minifantasy_bundle.zip')
base_out = 'E:/Projects/extraction-survivors/assets/minifantasy'
os.makedirs(base_out, exist_ok=True)

total_files = 0
total_packs = 0

for pack_name in outer.namelist():
    pack_data = outer.read(pack_name)
    try:
        inner = zipfile.ZipFile(io.BytesIO(pack_data))
    except Exception as e:
        print(f'SKIP {pack_name}: {e}')
        continue

    folder = re.sub(r'\.zip$', '', pack_name)
    folder = re.sub(r'[<>:"/|?*]', '_', folder)
    pack_dir = os.path.join(base_out, folder)

    pack_file_count = 0
    for member in inner.namelist():
        if member.endswith('/'):
            continue
        normalized = member.replace('\\', '/')
        parts = normalized.split('/')
        rel_path = '/'.join(parts[1:]) if len(parts) > 1 else parts[0]
        if not rel_path:
            continue
        safe_rel = os.path.join(*rel_path.split('/'))
        out_path = os.path.join(pack_dir, safe_rel)
        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        with open(out_path, 'wb') as f:
            f.write(inner.read(member))
        pack_file_count += 1

    total_files += pack_file_count
    total_packs += 1
    print(f'  [{total_packs:2d}/74] {folder}: {pack_file_count} files')

print(f'\nDone. {total_packs} packs, {total_files} total files -> {base_out}')

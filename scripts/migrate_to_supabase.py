#!/usr/bin/env python3
"""
Migrate notes from Netlify Blobs (exported JSON) to Supabase.
Usage:
  1. Export notes from Netlify Blobs to netlify_notes.json
  2. Fill .env.supabase.local.template and rename to .env.migration
  3. Run: python3 migrate_to_supabase.py
"""
import json, os, sys, uuid, pathlib
import requests
from datetime import datetime

# Load environment
env_path = pathlib.Path(__file__).parent.parent / '.env.migration'
if not env_path.exists():
    print('Missing .env.migration file. Copy .env.supabase.local.template and fill values.', file=sys.stderr)
    sys.exit(1)

env_vars = {}
with open(env_path) as f:
    for line in f:
        if '=' in line and not line.strip().startswith('#'):
            k, v = line.strip().split('=', 1)
            env_vars[k] = v

URL = env_vars.get('SUPABASE_URL') or env_vars.get('NEXT_PUBLIC_SUPABASE_URL')
KEY = env_vars.get('SUPABASE_KEY') or env_vars.get('SUPABASE_SERVICE_ROLE_KEY')

if not URL or not KEY:
    print('Missing SUPABASE_URL or SUPABASE_KEY in .env.migration', file=sys.stderr)
    sys.exit(1)

HEADERS = {
    'apikey': KEY,
    'Authorization': f'Bearer {KEY}',
    'Content-Type': 'application/json',
    'Prefer': 'resolution=merge-duplicates,return=minimal'
}

def uuid_from_id(old_id):
    """Convert old n123 format or UUID to UUID string"""
    if old_id.startswith('n'):
        return str(uuid.uuid5(uuid.NAMESPACE_DNS, old_id))
    try:
        uuid.UUID(old_id)
        return old_id
    except:
        return str(uuid.uuid5(uuid.NAMESPACE_DNS, old_id))

def migrate_notes(notes):
    """Migrate notes array to Supabase, return list of inserted IDs"""
    inserted = []
    for n in notes:
        nid = uuid_from_id(n.get('id', str(uuid.uuid4())))
        payload = {
            'id': nid,
            'title': n.get('title', '(no title)'),
            'content': n.get('content', ''),
            'category': n.get('category', 'General'),
            'tags': n.get('tags', []),
            'source': n.get('source', 'migrated'),
            'created_at': n.get('created_at', datetime.utcnow().isoformat()),
            'updated_at': n.get('updated_at', datetime.utcnow().isoformat())
        }
        r = requests.post(f'{URL}/rest/v1/notes', json=payload, headers=HEADERS)
        if r.status_code < 400:
            inserted.append(nid)
        else:
            print(f'Failed inserting note {nid}: {r.text}', file=sys.stderr)
    return inserted

if __name__ == '__main__':
    notes_file = pathlib.Path(__file__).parent.parent / 'netlify_notes.json'
    if not notes_file.exists():
        print('Missing netlify_notes.json - run Netlify rescue page first.', file=sys.stderr)
        sys.exit(1)

    notes = json.loads(notes_file.read_text())
    print(f'Migrating {len(notes)} notes...')
    migrated = migrate_notes(notes)
    print(f'Successfully migrated {len(migrated)} notes.')

    with open('migrated_notes_ids.txt', 'w') as f:
        for nid in migrated:
            f.write(nid + '\n')
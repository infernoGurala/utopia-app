import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

const GITHUB_PAT = process.env.GITHUB_PAT;
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;

if (!GITHUB_PAT || !SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
  console.error("Missing environment variables. Please provide GITHUB_PAT, SUPABASE_URL, and SUPABASE_SERVICE_KEY.");
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function fetchFromGitHub(url) {
  await sleep(100);
  const response = await fetch(url, {
    headers: {
      'Authorization': `Bearer ${GITHUB_PAT}`,
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28'
    }
  });

  if (!response.ok) {
    throw new Error(`GitHub API error: ${response.status} ${response.statusText} at ${url}`);
  }

  return response.json();
}

let stats = {
  foldersInserted: 0,
  notesInserted: 0,
  errors: 0
};

async function insertFolder(folder) {
  try {
    const { error } = await supabase.from('folders').upsert(folder, { onConflict: 'path', ignoreDuplicates: true });
    if (error) throw error;
    stats.foldersInserted++;
    console.log(`Inserted folder: ${folder.path}`);
  } catch (err) {
    console.error(`Failed to insert folder ${folder.path}:`, err.message);
    stats.errors++;
  }
}

async function insertNote(note) {
  try {
    const { error } = await supabase.from('notes').upsert(note, { onConflict: 'path', ignoreDuplicates: true });
    if (error) throw error;
    stats.notesInserted++;
    console.log(`Inserted note: ${note.path}`);
  } catch (err) {
    console.error(`Failed to insert note ${note.path}:`, err.message);
    stats.errors++;
  }
}

async function insertFolderIcon(icon) {
  try {
    const { error } = await supabase.from('folder_icons').upsert(icon, { onConflict: 'folder_path', ignoreDuplicates: true });
    if (error) {
        // If upsert fails due to missing unique constraint on folder_path, fallback to insert
        if (error.code === '42704' || error.message.includes('unique constraint')) {
           const { error: insertErr } = await supabase.from('folder_icons').insert(icon);
           if (insertErr) throw insertErr;
        } else {
           throw error;
        }
    }
    console.log(`Inserted folder icon for: ${icon.folder_path}`);
  } catch (err) {
    console.error(`Failed to insert folder icon ${icon.folder_path}:`, err.message);
    stats.errors++;
  }
}

async function migrateLegacy() {
  console.log("Migrating utopia-content (legacy)...");
  const owner = "infernoGurala";
  const repo = "utopia-content";
  
  try {
    const treeData = await fetchFromGitHub(`https://api.github.com/repos/${owner}/${repo}/git/trees/main?recursive=1`);
    
    let hiddenPaths = [];
    const hiddenFile = treeData.tree.find(e => e.path === '.utopia-hidden');
    if (hiddenFile) {
      try {
        const fileData = await fetchFromGitHub(`https://api.github.com/repos/${owner}/${repo}/contents/${hiddenFile.path}`);
        const content = Buffer.from(fileData.content, 'base64').toString('utf-8');
        try {
          hiddenPaths = JSON.parse(content);
        } catch (e) {
          hiddenPaths = content.split(',').map(s => s.trim()).filter(s => s);
        }
      } catch (err) {
        console.error("Error fetching/parsing .utopia-hidden:", err.message);
        stats.errors++;
      }
    }

    for (const entry of treeData.tree) {
      if (entry.path === 'README.md' || entry.path === '.utopia-hidden' || entry.path.split('/').pop().startsWith('.')) {
        continue;
      }

      if (entry.type === 'tree') {
        const parts = entry.path.split('/');
        const name = parts[parts.length - 1];
        const parent_path = parts.length > 1 ? parts.slice(0, -1).join('/') : null;
        const is_hidden = hiddenPaths.includes(entry.path);

        await insertFolder({
          path: entry.path,
          name: name,
          parent_path: parent_path,
          scope: 'legacy',
          is_hidden: is_hidden,
          sort_index: 0,
          created_by: null
        });
      } else if (entry.type === 'blob' && entry.path.endsWith('.md')) {
        try {
          const parts = entry.path.split('/');
          const name = parts[parts.length - 1].replace('.md', '');
          const folder_path = parts.length > 1 ? parts.slice(0, -1).join('/') : null;

          const fileData = await fetchFromGitHub(`https://api.github.com/repos/${owner}/${repo}/contents/${entry.path}`);
          const content = Buffer.from(fileData.content, 'base64').toString('utf-8');

          await insertNote({
            path: entry.path,
            name: name,
            folder_path: folder_path,
            content: content,
            scope: 'legacy',
            sort_index: 0,
            created_by: null
          });
        } catch (err) {
          console.error(`Failed to process legacy note ${entry.path}:`, err.message);
          stats.errors++;
        }
      }
    }
  } catch (err) {
    console.error("Failed to migrate legacy repo:", err.message);
    stats.errors++;
  }
}

async function migrateGlobal() {
  console.log("\nMigrating utopia-global...");
  const owner = "theutopiadomain";
  const repo = "utopia-global";
  
  try {
    let branch = 'main';
    try {
      const repoInfo = await fetchFromGitHub(`https://api.github.com/repos/${owner}/${repo}`);
      if (repoInfo && repoInfo.default_branch) {
        branch = repoInfo.default_branch;
      }
    } catch (e) {
      console.warn("Could not fetch repo info, defaulting to main branch.");
    }

    const treeData = await fetchFromGitHub(`https://api.github.com/repos/${owner}/${repo}/git/trees/${branch}?recursive=1`);

    for (const entry of treeData.tree) {
      const filename = entry.path.split('/').pop();
      if (filename === '.keep' || filename === 'README.md') {
        continue;
      }

      if (filename === '.icons.json') {
        try {
          const fileData = await fetchFromGitHub(`https://api.github.com/repos/${owner}/${repo}/contents/${entry.path}`);
          const content = Buffer.from(fileData.content, 'base64').toString('utf-8');
          const icons = JSON.parse(content);
          const folder_path = entry.path.split('/').slice(0, -1).join('/') || '';
          
          for (const [subfolder, icon_key] of Object.entries(icons)) {
            const targetFolder = folder_path ? `${folder_path}/${subfolder}` : subfolder;
            await insertFolderIcon({
              folder_path: targetFolder,
              icon_key: icon_key
            });
          }
        } catch (err) {
          console.error(`Failed to process .icons.json at ${entry.path}:`, err.message);
          stats.errors++;
        }
        continue;
      }

      const parts = entry.path.split('/');
      let scope = 'university';
      let university_id = parts[0];
      let class_id = null;

      if (parts.length === 1) {
        scope = 'university';
      } else if (entry.path.includes('/Community/')) {
        scope = 'community';
      } else if (entry.path.includes('/Notes/')) {
        scope = 'class';
        class_id = parts[1];
      } else {
        scope = 'class';
        if (parts.length > 1 && !entry.path.includes('/Community/')) {
           class_id = parts[1];
        }
      }

      if (entry.type === 'tree') {
        const name = parts[parts.length - 1];
        const parent_path = parts.length > 1 ? parts.slice(0, -1).join('/') : null;

        await insertFolder({
          path: entry.path,
          name: name,
          parent_path: parent_path,
          scope: scope,
          university_id: university_id,
          class_id: class_id,
          is_hidden: false,
          sort_index: 0,
          created_by: null
        });
      } else if (entry.type === 'blob' && entry.path.endsWith('.md')) {
        try {
          const name = parts[parts.length - 1].replace('.md', '');
          const folder_path = parts.length > 1 ? parts.slice(0, -1).join('/') : '';

          const fileData = await fetchFromGitHub(`https://api.github.com/repos/${owner}/${repo}/contents/${entry.path}`);
          const content = Buffer.from(fileData.content, 'base64').toString('utf-8');

          await insertNote({
            path: entry.path,
            name: name,
            folder_path: folder_path,
            content: content,
            scope: scope,
            university_id: university_id,
            class_id: class_id,
            sort_index: 0,
            created_by: null
          });
        } catch (err) {
          console.error(`Failed to process global note ${entry.path}:`, err.message);
          stats.errors++;
        }
      }
    }
  } catch (err) {
    console.error("Failed to migrate global repo:", err.message);
    stats.errors++;
  }
}

async function main() {
  await migrateGlobal();

  console.log("\nMigration Summary:");
  console.log(`Folders Inserted: ${stats.foldersInserted}`);
  console.log(`Notes Inserted: ${stats.notesInserted}`);
  console.log(`Errors: ${stats.errors}`);
}

main();

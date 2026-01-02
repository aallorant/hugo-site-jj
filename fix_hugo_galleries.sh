#!/bin/bash

# Fix Hugo Gallery Structure
# This script converts _index.md to index.md in folders that contain images
# This makes them "leaf bundles" which properly load images as resources

cd "$(dirname "$0")"

echo "🔧 Fixing Hugo gallery structure..."
echo ""

# Folders that should remain as branch bundles (they contain sub-galleries, not images)
BRANCH_FOLDERS=(
    "content/production"
    "content/production/dessins"
)

# Function to check if folder should stay as branch bundle
is_branch_folder() {
    local folder="$1"
    for branch in "${BRANCH_FOLDERS[@]}"; do
        if [[ "$folder" == "$branch" ]]; then
            return 0
        fi
    done
    return 1
}

# Counter for changes
changes=0

# Find all _index.md files
find content -name "_index.md" | while read -r file; do
    folder=$(dirname "$file")
    
    # Skip if this should remain a branch bundle
    if is_branch_folder "$folder"; then
        echo "⏭️  Keeping branch bundle: $folder/_index.md"
        continue
    fi
    
    # Check if folder contains images
    if ls "$folder"/*.jpg >/dev/null 2>&1 || ls "$folder"/*.jpeg >/dev/null 2>&1 || ls "$folder"/*.png >/dev/null 2>&1; then
        echo "✅ Converting to leaf bundle: $folder"
        mv "$file" "$folder/index.md"
        ((changes++))
    else
        echo "⏭️  No images, keeping as-is: $folder"
    fi
done

echo ""
echo "📁 Creating index.md for image-only folders..."

# Handle the dessins subfolders (Mode, Nus, Portraits, etc.) that have images but no markdown
for subfolder in content/production/dessins/*/; do
    if [[ -d "$subfolder" ]]; then
        folder_name=$(basename "$subfolder")
        
        # Skip if already has index.md or _index.md
        if [[ -f "${subfolder}index.md" ]] || [[ -f "${subfolder}_index.md" ]]; then
            echo "⏭️  Already has markdown: $subfolder"
            continue
        fi
        
        # Check if has images
        if ls "$subfolder"*.jpg >/dev/null 2>&1; then
            echo "✅ Creating index.md for: $subfolder"
            
            # Create a nice French title from folder name
            title="$folder_name"
            
            cat > "${subfolder}index.md" << EOF
---
title: "$title"
type: "gallery"
---
EOF
            ((changes++))
        fi
    fi
done

echo ""
echo "🎉 Done! Made changes to gallery structure."
echo ""
echo "Next steps:"
echo "1. Run: hugo server"
echo "2. Check if images now appear"
echo "3. If good, commit and push to deploy"

Folder System (GitHub)
===========================

Repository Root  
├── University A  
│ ├── Class A  
│ └── Class B  
└── University B  
├── Class C  
└── Class D


## Rules
- University name from Colleges API is parent folder.
- Changing university in settings switches class view; previous classes retained.
- Unique class ID (UUID) differentiates same-named classes.
- User can join unlimited classes, create up to 10.
- Max 6 writers per class (creator + 5 others). Only creator can edit writers.

## UI
- **Community Notes** pinned at top of library.
- Clean, minimalist, medium rounded square cards.

## Class Sharing
- Join via link: `classes.inferalis.space/join/{classCode}`
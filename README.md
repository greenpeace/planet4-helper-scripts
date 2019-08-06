# Helper scripts for Planet 4

Common post-install and maintenance tasks.

To be incorporated into CI workflows at some point.

## Quickstart

```bash

# Configure environment
./configure.sh [<release-name>] [<kubernetes-namespace>]

# Update release configuration
make

```

### Final go-live database updates

Example:
```bash

# Configure environment
./configure.sh planet4-flibble-master flibble

# Perform database search and replace
make update-links

# Flush the redis cache
make flush
```

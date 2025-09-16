import dnf

base = dnf.Base()
base.read_all_repos()

# Iterate through all enabled repositories
for repo in base.repos.iter_enabled():
    try:
        repo.load()
        content = repo.get_metadata_content('primary')
        print(f"--- Metadata for {repo.id} ---")
        print(content)
        print("\n")
    except Exception as e:
        print(f"Could not load metadata for repo {repo.id}: {e}")

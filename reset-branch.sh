new=$(git commit-tree HEAD^{tree} -m "initial import") && echo "New commit: $new" && git reset --hard "$new" && git log --oneline

git push --force origin master

# Where is the documentation kept?

Some of it is kept here, like a general project overviews and some integration docs.
But most of it is held elsewhere.

Each Cumulus project has its own little docs/ fiefdom in its own repo.
This way, docs can update as code changes more easily.

# When does the documentation get updated?

- Every time this repo is updated, the documentation is rebuilt.
- It can also be rebuilt manually in GitHub.
- But mostly, it will be updated when other project repos sends it a GitHub event,
  to rebuild docs.

# Conventions for repo documentation
- Everything in `docs/` is going to be accessible on public docs site (direct URL at minimum)
  - Which might affect the tone of your text as well as which files go in there
  - Except for `docs/README.md` which we won't include, so that you can explain what the
    folder is about and point at this repo.
  - Note that you can put sample json, yaml, etc. in there.
- Include a `docs/index.md` as your root & intro doc
- Use a toplevel title that makes sense in context of the whole Cumulus project
  - i.e. "Library" instead of "Cumulus Library" probably (though in your doc prose and headers,
    "Cumulus Library" would make sense -- but your main index.md title will be used in the main
    documentation sidebar)
- Use caution when linking:
  - When linking to _code_, use absolute links
  - When linking to other docs _inside_ your repo, use relative links
  - When linking to other docs _outside_ your repo, only link to the following URLs,
    that we promise will exist:
    - https://docs.smarthealthit.org/cumulus/
    - https://docs.smarthealthit.org/cumulus/library/
  - That rule is designed to allow each repo to move files around at will, without breaking the
    world. But don't rename files willy-nilly, since any links out there on the web or user
    bookmarks/history might break if a filename changes.
- Consider audience & tone when editing docs, to help keep a uniform writing style.
  - It can be helpful to consider what [sort of document](https://diataxis.fr/) you
    are writing.

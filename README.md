# cihm-metadatabus

Docker build environment and libraries for key portions of the metadata bus.

The file `env-dist` has the environment variables that must be put into a `.env` file, adding in passwords as required.

The `./run` is used to run on a local machine for development/testing, before pushing to the Docker registry.


A script exists for building and pushing images which should be used:

```
russell@russell-XPS-13-7390:~/git/cihm-metadatabus$ ./deployimage.sh 
```



## CIHM-Meta

Core of Metadtabus. See [HISTORY.md](CIHM-Meta/HISTORY.md) for some of the history of the code.

Tooks:

* dmdtask - handles Descriptive MetaData tasks, which process and update databases with metadata
* hammer2 - Sources data from the `access` and other databases to create the cache files that will be used by Solr search and presentation (Currently CAP).
* importocr - Temporary: imports OCR data from preservation storage (AIP format) to store in the access platform.
* ocrtask - Handles OCR related tasks -- exporting Canvas images to filesystem used for OCR, and importing results (ALTO XML, PDF) into Access storage for Canvases.
* presentation-diff - Temporary: compares the old and new `copresentation` databases to find differences between the old and new, part of the migration.
* press2 - Temporary: Other half of `hammer2` functionality that [will be merged](https://github.com/crkn-rcdr/cihm-metadatabus/issues/23). The old metadatabus had this split as staff used tools which managed fields in the internalmeta database. This is no longer the case with the new tools.
* smelter - Microservice responsible for "Import into Access", copying data from presertavion storage (AIP files, METS data) to Access storage (manifests and canvases)
* solrstream - copies data from CouchDB `cosearch` database to Solr `cosearch` core,using the CouchDB [/db/_changes](https://docs.couchdb.org/en/latest/api/database/changes.html) interface.
* walk-canvas-orphan - Walks through canvases looking for any which are not referenced by any manifest. This is the first of a set of tools to walk databases to ensure data integrity across multiple data sources.  More will be written to check things such as whether all files in access storage are appropriately references in CouchDB documents (any missing, any extra, etc).

Most of the libraries have names which make it obvious which of the above tools they are part of. Exceptions are:

* CIHM::Meta::REST::cantaloupe  -  Cantaloupe makes use of an authentication system which injects headers. This is where this is set up
* CIHM::Meta::REST::UserAgent - This is the user agent for communicating with Cantaloupe and injecting the headers.


## CIHM-Normalise

Library temporary outside of CIHM::Meta for historical reasons.  Will [soon be merged](https://github.com/crkn-rcdr/cihm-metadatabus/issues/19).

## CIHM-Swift

Separate submodule of https://github.com/crkn-rcdr/CIHM-Swift which has common functionality created for interacting with [OpenStack Swift](https://docs.openstack.org/swift/latest/). Module code includes comments pointing at the documentation for the functinality implimented.


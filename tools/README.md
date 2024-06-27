# cherryPick.sh 

Given one or more existing commits, the script applies the change each one introduces to a newly created branch

1) Pulling envolved branchs
1) Created new cherry pick branch
1) Ordering commits by date  
1) Creating pull request

## Script execution



###### Usage: 
``` bash
bash cherryPick.sh <release branch name> <Jira issuer> [clear | <cherry commit id>]
```

## Examples
Insert new commit

	- bash cherryPick.sh release/23.12 TSW-123456 f450568d0edea333501cc6f2b80c1e8e74ff290e

Finalize cherry pick

	- bash cherryPick.sh release/23.12 TSW-123456

Clear (restart) cherry pick

	- bash cherryPick.sh release/23.12 TSW-123456 clear


## Procedimentos

1) 


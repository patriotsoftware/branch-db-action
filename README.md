# branch-db-action

This action is intended to share a common set of steps we use to
create or delete a branch database in dev.

- Checkout code
- Authenticate
- Create or Delete a branch

## Parameters

#### 'branch_action' (required)
Specify 'Create', 'Recreate' or 'Delete' action to either create, recreate or delete a branch database. The 'Recreate' options deletes if exists then creates.

#### 'github_ref_name' (required)
GitHub property 'github.ref' used to determine the branch name.

#### 'github_actor' (required)
GitHub property 'github.actor' to capture who is initiating the action.

#### 'sql_dump' (optional)
Set to false by default. Used for debugging. Upload dump.sql file as dump-sql artifact to workflow.

#### 'aws_access_key' (required)
Access key for Aws upload.

#### 'aws_secret_key' (required)
Secret key for Aws upload.

#### 'aws_region' (optional)
Aws region used. Default is 'us-east-1'.

#### 'database_cluster' (optional)
Database cluster used. Default is 'Service'.

## Sample Use

```
  branch-db-action:
    name:  Create or Delete Branch Database
    runs-on: psidev-linux
    steps:
    - name: "Create a branch Database"
      uses: patriotsoftware/branch-db-action@v1
      with:
        branch_action: 'Create'
        github_ref_name: ${{ github.ref_name }}
        aws_access_key: ${{ secrets.DEV_AWS_ACCESS_KEY_ID }}
        aws_secret_key: ${{ secrets.DEV_AWS_SECRET_ACCESS_KEY }}

    - name: "Delete a branch database"
      uses: patriotsoftware/branch-db-action@v1
      with:
        branch_action: 'Delete'
        github_ref_name: ${{ github.ref_name }}
        aws_access_key: ${{ secrets.DEV_AWS_ACCESS_KEY_ID }}
        aws_secret_key: ${{ secrets.DEV_AWS_SECRET_ACCESS_KEY }}
```


# tsuru-docs

Release repository for tsuru documentation.

##Building

In order to build the documentation, you'll need to run the command below:

```
% ./make.bash
```

It will generate the whole documentation in the build directory. The command
above uses [Sphinx](http://sphinx-doc.org/) for building the documentation, and
it will install required Python dependencies, please ensure that you're inside
a virtualenv before running it.

##Deploying to tsuru

The generated code can be easily deployed to a tsuru static application. In
order to do that, run the following command after building the documentation:

```
% tsuru app-deploy -a <app-name> build
```

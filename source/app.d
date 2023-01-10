module app;

version (unittest) {
    int main() {
        return 0;
    }
} else {
    int main(string[] args) {
        import quartz.cli.app : runQuartz;
        return runQuartz(args);
    }
}

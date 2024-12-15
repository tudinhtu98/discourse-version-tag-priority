export default {
  resource: "admin.adminPlugins",
  path: "/plugins",
  map() {
    this.route("version-tag");
  },
};

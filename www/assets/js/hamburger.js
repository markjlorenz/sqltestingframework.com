function toggleBurger() {
  var menuLinks = document.getElementById("menu-links");
    if (menuLinks.style.display === "block") {
      menuLinks.style.display = "none";
    } else {
      menuLinks.style.display = "block";
  }
}

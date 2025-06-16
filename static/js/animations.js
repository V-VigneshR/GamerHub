// Card fade-in animation
document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('.card').forEach((c, i) => {
    c.style.opacity = 0;
    setTimeout(() => c.style.transition = 'opacity 0.6s ease-in-out', 100 * i);
    setTimeout(() => c.style.opacity = 1, 100 * i + 200);
  });

  // Smooth scroll for in-page anchor links like #about
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener("click", function (e) {
      e.preventDefault();
      const target = document.querySelector(this.getAttribute("href"));
      if (target) {
        target.scrollIntoView({
          behavior: "smooth"
        });
      }
    });
  });
});

// Initialize Particles.js with More Fluid Interaction
particlesJS("particles-js", {
  "particles": {
    "number": { "value": 60, "density": { "enable": true, "value_area": 800 } },
    "color": { "value": ["#333333", "#666666", "#78b4ff", "#F4F4F4"] },
    "shape": { "type": "circle", "stroke": { "width": 0, "color": "#000000" } },
    "opacity": { "value": 0.5, "random": true, "anim": { "enable": true, "speed": 0.5, "opacity_min": 0.1, "sync": false } },
    "size": { "value": 4, "random": true, "anim": { "enable": false, "speed": 40, "size_min": 0.1, "sync": false } },
    "line_linked": { "enable": true, "distance": 200, "color": "#666666", "opacity": 0.4, "width": 1 },
    "move": { "enable": true, "speed": 2.0, "direction": "none", "random": true, "straight": false, "out_mode": "out", "bounce": true }
  },
  "interactivity": {
    "detect_on": "canvas",
    "events": {
      "onhover": { "enable": true, "mode": ["bubble", "repulse"] },
      "onclick": { "enable": true, "mode": "push" },
      "resize": true
    },
    "modes": {
      "bubble": { "distance": 200, "size": 8, "duration": 0.5, "opacity": 0.7 },
      "repulse": { "distance": 80, "duration": 0.4 },
      "push": { "particles_nb": 4 }
    }
  },
  "retina_detect": true
});

function isMobile() {
	var agentDetails = navigator.userAgent;
  return (/Android|Mobi|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(agentDetails) );
}

// Feature Cards Slide-In
const featureCards = document.querySelectorAll('.feature-card');
const observerOptions = {
    root: null,
    rootMargin: isMobile() ? '-100px' : '-200px', // Smaller margin for mobile
    threshold: isMobile() ? 0.05 : 0.1 // Less strict threshold for mobile
};
const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
	        	console.log('Card intersecting:', entry.isIntersecting, entry.target);
            entry.target.classList.add('visible');
            observer.unobserve(entry.target);
        }
    });
}, observerOptions);
featureCards.forEach(card => observer.observe(card));

featureCards.forEach(card => {
    const rect = card.getBoundingClientRect();
    if (rect.top < window.innerHeight && rect.bottom >= 0) {
        card.classList.add('visible');
    } else {
        observer.observe(card);
    }
});

// Draggable Tabs with Touch Support
document.querySelectorAll('.placeholder-tab').forEach(tab => {
  let isDragging = false;
  let startX = 0;
  let currentX = 10; // Initial left position
  const initialPadding = 10; // Match the initial left position for aesthetic offset
  const parent = tab.parentElement;
  const scaleFactor = 1.2;
  let baseWidth;

  // Function to calculate the base width (unscaled), including padding
  const calculateBaseWidth = () => {
    const parentStyles = getComputedStyle(parent);
    let width = parent.offsetWidth;
    // Subtract borders only (not padding, as tab slides within the content box including padding)
    width = width
      - parseFloat(parentStyles.borderLeftWidth)
      - parseFloat(parentStyles.borderRightWidth);
    return Math.max(width, 0); // Ensure width is not negative
  };

  // Function to calculate the tab width, accounting for borders
  const calculateTabWidth = () => {
    const tabStyles = getComputedStyle(tab);
    let width = tab.offsetWidth;
    // Account for borders (1px on left and right)
    width = width
      - parseFloat(tabStyles.borderLeftWidth)
      - parseFloat(tabStyles.borderRightWidth);
    return Math.max(width, 0);
  };

  // Initial calculation
  baseWidth = calculateBaseWidth();
  let tabWidth = calculateTabWidth();
  let scaledWidth = baseWidth * scaleFactor;

  // Recalculate on window resize
  window.addEventListener('resize', () => {
    baseWidth = calculateBaseWidth();
    tabWidth = calculateTabWidth();
    scaledWidth = baseWidth * scaleFactor;
    const maxLeft = baseWidth - tabWidth - initialPadding; // Respect initial padding on the right
    currentX = Math.min(currentX, maxLeft);
    currentX = Math.max(currentX, initialPadding); // Ensure it doesn't go below initial padding
    tab.style.left = `${currentX}px`;
  });

  // Mouse Events
  tab.addEventListener('mousedown', (e) => {
    e.preventDefault();
    isDragging = true;
    baseWidth = calculateBaseWidth();
    tabWidth = calculateTabWidth();
    scaledWidth = baseWidth * scaleFactor;
    const parentRect = parent.getBoundingClientRect();
    // Adjust startX to account for the panel's scaled position
    const unscaledMouseX = (e.clientX - parentRect.left) / scaleFactor;
    startX = unscaledMouseX - currentX;
    tab.classList.add('dragging');
    parent.classList.add('dragging');
  });

  document.addEventListener('mousemove', (e) => {
    if (!isDragging) return;
    e.preventDefault();

    const parentRect = parent.getBoundingClientRect();
    // Convert mouse position to unscaled coordinates
    const unscaledMouseX = (e.clientX - parentRect.left) / scaleFactor;
    const minLeft = initialPadding; // Respect initial padding on the left
    const maxLeft = baseWidth - tabWidth - initialPadding; // Respect initial padding on the right
    const newLeft = Math.min(Math.max(unscaledMouseX - startX, minLeft), maxLeft);

    currentX = newLeft;
    tab.style.left = `${currentX}px`;
  });

  document.addEventListener('mouseup', () => {
    isDragging = false;
    tab.classList.remove('dragging');
  });

  // Touch Events
  tab.addEventListener('touchstart', (e) => {
    e.preventDefault();
    isDragging = true;
    baseWidth = calculateBaseWidth();
    tabWidth = calculateTabWidth();
    scaledWidth = baseWidth * scaleFactor;
    const parentRect = parent.getBoundingClientRect();
    // Adjust startX to account for the panel's scaled position
    const unscaledTouchX = (e.touches[0].clientX - parentRect.left) / scaleFactor;
    startX = unscaledTouchX - currentX;
    tab.classList.add('dragging');
    parent.classList.add('dragging');
  });

  document.addEventListener('touchmove', (e) => {
    if (!isDragging) return;
    e.preventDefault();

    const parentRect = parent.getBoundingClientRect();
    // Convert touch position to unscaled coordinates
    const unscaledTouchX = (e.touches[0].clientX - parentRect.left) / scaleFactor;
    const minLeft = initialPadding; // Respect initial padding on the left
    const maxLeft = baseWidth - tabWidth - initialPadding; // Respect initial padding on the right
    const newLeft = Math.min(Math.max(unscaledTouchX - startX, minLeft), maxLeft);

    currentX = newLeft;
    tab.style.left = `${currentX}px`;
  });

  document.addEventListener('touchend', () => {
    isDragging = false;
    tab.classList.remove('dragging');
  });

  parent.addEventListener('mouseleave', () => {
    if (!isDragging) parent.classList.remove('dragging');
  });

  parent.addEventListener('touchend', () => {
    if (!isDragging) parent.classList.remove('dragging');
  });
});

// Screenshot Animation on Hover
document.querySelectorAll('.placeholder').forEach(placeholder => {
  const img = placeholder.querySelector('.placeholder-img');
  const stillSrc = img.src;
  const animatedSrc = img.getAttribute('data-animated-src');

  placeholder.addEventListener('mouseenter', () => {
    img.src = animatedSrc;
  });

  placeholder.addEventListener('mouseleave', () => {
    img.src = stillSrc;
  });

  // Fallback for touch devices: toggle animation on tap
  placeholder.addEventListener('touchstart', (e) => {
    e.preventDefault();
    if (img.src === stillSrc) {
      img.src = animatedSrc;
    } else {
      img.src = stillSrc;
    }
  });
});

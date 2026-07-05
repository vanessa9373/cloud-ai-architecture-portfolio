/* ============================================================
   Vanessa Awo - Portfolio JavaScript
   Solutions Architect, Cloud & DevOps Engineer, SRE
   Hybrid single-page + separate pages version
   ============================================================ */

if (location.hash === '#home') {
  history.replaceState(null, '', location.pathname + location.search);
}

document.addEventListener('DOMContentLoaded', () => {

  /* ---------- AOS (ANIMATE ON SCROLL) ---------- */
  if (typeof AOS !== 'undefined') {
    AOS.init({
      duration: 400,
      easing: 'ease-out',
      once: true,
      offset: 60,
      disable: 'mobile'
    });
  }


  /* ---------- PAGE LOADER ---------- */
  const pageLoader = document.getElementById('page-loader');
  if (pageLoader) {
    const minTime = 400;
    const startTime = performance.now();
    let dismissed = false;

    function dismissLoader() {
      if (dismissed) return;
      dismissed = true;
      const elapsed = performance.now() - startTime;
      const remaining = Math.max(0, minTime - elapsed);
      setTimeout(() => pageLoader.classList.add('hidden'), remaining);
    }

    // Hard cap: dismiss after 600ms even if CDN resources are still loading
    const hardCap = setTimeout(dismissLoader, 600);

    if (document.readyState === 'complete') {
      clearTimeout(hardCap);
      dismissLoader();
    } else {
      window.addEventListener('load', () => { clearTimeout(hardCap); dismissLoader(); });
    }
  }


  /* ---------- SCROLL PROGRESS BAR ---------- */
  const scrollProgress = document.getElementById('scroll-progress');
  if (scrollProgress) {
    window.addEventListener('scroll', () => {
      const docHeight = document.documentElement.scrollHeight - window.innerHeight;
      if (docHeight > 0) {
        scrollProgress.style.width = Math.min((window.scrollY / docHeight) * 100, 100) + '%';
      }
    }, { passive: true });
  }


  /* ---------- BUTTON RIPPLE - removed ---------- */


  /* ---------- MOBILE NAVIGATION ---------- */
  const navToggle = document.getElementById('nav-toggle');
  const navMenu = document.getElementById('nav-menu');

  if (navToggle && navMenu) {
    navToggle.addEventListener('click', () => {
      navMenu.classList.toggle('open');
      navToggle.classList.toggle('open');
    });

    // Close menu when a link is clicked (including anchor links)
    document.querySelectorAll('.nav-link').forEach(link => {
      link.addEventListener('click', () => {
        navMenu.classList.remove('open');
        navToggle.classList.remove('open');
      });
    });
  }


  /* ---------- CLEAN HASH URLS: intercept all anchor clicks ---------- */
  document.querySelectorAll('a[href^="#"]').forEach(link => {
    link.addEventListener('click', e => {
      const hash = link.getAttribute('href');
      if (!hash || hash === '#') return;
      const target = document.querySelector(hash);
      if (target) {
        e.preventDefault();
        target.scrollIntoView({ behavior: 'smooth' });
        history.replaceState(null, '', location.pathname + location.search);
      }
    });
  });


  /* ---------- NAVBAR SCROLL EFFECT ---------- */
  const navbar = document.getElementById('navbar');
  const backToTop = document.getElementById('back-to-top');
  const isInteriorPage = !document.querySelector('.hero');

  // On interior pages, always show the scrolled navbar style
  if (isInteriorPage && navbar) {
    navbar.classList.add('scrolled');
  }

  window.addEventListener('scroll', () => {
    if (navbar) {
      if (isInteriorPage || window.scrollY > 60) {
        navbar.classList.add('scrolled');
      } else {
        navbar.classList.remove('scrolled');
      }
    }

    if (backToTop) {
      if (window.scrollY > 500) {
        backToTop.classList.add('visible');
      } else {
        backToTop.classList.remove('visible');
      }
    }
  });

  if (backToTop) {
    backToTop.addEventListener('click', () => {
      window.scrollTo({ top: 0, behavior: 'smooth' });
    });
  }


  /* ---------- ACTIVE NAV LINK - PATHNAME-BASED ---------- */
  const navLinks = document.querySelectorAll('.nav-link');
  const path = window.location.pathname;

  // Map page filenames to nav labels (only separate pages)
  const pageMap = {
    'index.html': 'Home',
    'projects.html': 'Projects',
    'blog.html': 'Blog'
  };

  // Determine current page
  let currentPage = 'Home';
  for (const [file, label] of Object.entries(pageMap)) {
    if (path.endsWith(file)) {
      currentPage = label;
      break;
    }
  }
  // Handle bare directory (/) as Home
  if (path.endsWith('/') || path === '') currentPage = 'Home';
  // Post pages → highlight Blog
  if (path.includes('/posts/')) currentPage = 'Blog';

  navLinks.forEach(link => {
    link.classList.remove('active');
    if (link.textContent.trim() === currentPage) {
      link.classList.add('active');
    }
  });


  /* ---------- SCROLL SPY (Home page only) ---------- */
  const isHomePage = document.querySelector('.hero');
  if (isHomePage) {
    const sectionIdToNav = {
      'home': 'Home',
      'about': 'About',
      'skills': 'Skills',
      'experience': 'Experience',
      'certifications': 'Experience',
      'contact': 'Contact'
    };

    const spySections = document.querySelectorAll('section[id]');
    if (spySections.length > 0) {
      const spyObserver = new IntersectionObserver(entries => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            const id = entry.target.id;
            const navLabel = sectionIdToNav[id];
            if (navLabel) {
              navLinks.forEach(link => {
                link.classList.remove('active');
                if (link.textContent.trim() === navLabel) {
                  link.classList.add('active');
                }
              });
            }
          }
        });
      }, { threshold: 0.15, rootMargin: '-80px 0px -40% 0px' });

      spySections.forEach(section => spyObserver.observe(section));
    }
  }


  /* ---------- TYPED TEXT - static display ---------- */
  // Static role title; no animation loop needed


  /* ---------- COUNTER ANIMATION (Home page only) ---------- */
  const statNumbers = document.querySelectorAll('.stat-number');
  let countersAnimated = false;

  function animateCounters() {
    if (countersAnimated) return;

    statNumbers.forEach(stat => {
      const target = parseInt(stat.getAttribute('data-target'));
      const duration = 600;
      const start = performance.now();

      function updateCounter(now) {
        const elapsed = now - start;
        const progress = Math.min(elapsed / duration, 1);
        const eased = 1 - Math.pow(1 - progress, 3);
        stat.textContent = Math.floor(eased * target);

        if (progress < 1) {
          requestAnimationFrame(updateCounter);
        } else {
          stat.textContent = target;
        }
      }

      requestAnimationFrame(updateCounter);
    });

    countersAnimated = true;
  }

  const heroStats = document.querySelector('.hero-stats');
  if (heroStats) {
    const observer = new IntersectionObserver(entries => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          animateCounters();
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: 0.5 });

    observer.observe(heroStats);
  }


  /* ---------- SKILL TABS ---------- */
  const skillTabs = document.querySelectorAll('.skill-tab');
  const skillPanels = document.querySelectorAll('.skill-panel');

  if (skillTabs.length > 0) {
    skillTabs.forEach(tab => {
      tab.addEventListener('click', () => {
        const target = tab.getAttribute('data-tab');

        skillTabs.forEach(t => t.classList.remove('active'));
        tab.classList.add('active');

        skillPanels.forEach(panel => {
          panel.classList.remove('active');
          if (panel.id === `panel-${target}`) {
            panel.classList.add('active');
            animateSkillBars(panel);
          }
        });
      });
    });
  }

  function animateSkillBars(container) {
    const fills = container.querySelectorAll('.skill-fill');
    fills.forEach(fill => {
      fill.style.width = '0';
      setTimeout(() => {
        const width = fill.getAttribute('data-width');
        fill.style.width = width + '%';
      }, 100);
    });
  }

  const skillsSection = document.getElementById('skills');
  if (skillsSection) {
    const observer = new IntersectionObserver(entries => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          const activePanel = skillsSection.querySelector('.skill-panel.active');
          if (activePanel) animateSkillBars(activePanel);
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: 0.2 });

    observer.observe(skillsSection);
  }


  /* ---------- PROJECT FILTERS (Projects page only) ---------- */
  const filterBtns = document.querySelectorAll('.filter-btn:not(.blog-filter-btn)');
  const projectCards = document.querySelectorAll('.project-card');

  if (filterBtns.length > 0) {
    filterBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        const filter = btn.getAttribute('data-filter');

        filterBtns.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');

        projectCards.forEach(card => {
          const category = card.getAttribute('data-category');
          if (filter === 'all' || category === filter) {
            card.classList.remove('hidden');
            card.style.animation = 'fadeIn 0.4s ease forwards';
          } else {
            card.classList.add('hidden');
          }
        });
      });
    });

    // Add fadeIn keyframes dynamically
    const style = document.createElement('style');
    style.textContent = `
      @keyframes fadeIn {
        from { opacity: 0; transform: translateY(10px); }
        to { opacity: 1; transform: translateY(0); }
      }
    `;
    document.head.appendChild(style);
  }


  /* ---------- SCROLL REVEAL ANIMATION ---------- */
  const revealElements = document.querySelectorAll(
    '.about-grid, .skill-card, .project-card, .timeline-item, .cert-card, .contact-grid, .blog-card'
  );

  revealElements.forEach(el => el.classList.add('reveal'));

  const revealObserver = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
        revealObserver.unobserve(entry.target);
      }
    });
  }, { threshold: 0.1, rootMargin: '0px 0px -40px 0px' });

  revealElements.forEach(el => revealObserver.observe(el));


  /* ---------- CONTACT FORM ---------- */
  const contactForm = document.getElementById('contact-form');
  if (contactForm) {
    const submitBtn = contactForm.querySelector('button[type="submit"]');

    contactForm.addEventListener('submit', () => {
      if (submitBtn) {
        submitBtn.textContent = 'Sending...';
        submitBtn.disabled = true;
      }
    });
  }


  /* ---------- PARTICLE NETWORK CANVAS (Hero only) ---------- */
  const heroSection = document.querySelector('.hero');
  if (heroSection) {
    const canvas = document.createElement('canvas');
    canvas.id = 'particle-canvas';
    heroSection.appendChild(canvas);
    const ctx = canvas.getContext('2d');

    let particles = [];
    const isMobile = window.innerWidth < 768;
    const PARTICLE_COUNT = isMobile ? 25 : 55;
    const CONNECT_DIST = 120;

    function resizeCanvas() {
      canvas.width = heroSection.offsetWidth;
      canvas.height = heroSection.offsetHeight;
    }
    resizeCanvas();
    window.addEventListener('resize', resizeCanvas);

    function createParticles() {
      particles = [];
      for (let i = 0; i < PARTICLE_COUNT; i++) {
        particles.push({
          x: Math.random() * canvas.width,
          y: Math.random() * canvas.height,
          vx: (Math.random() - 0.5) * 0.6,
          vy: (Math.random() - 0.5) * 0.6,
          r: Math.random() * 2 + 1
        });
      }
    }
    createParticles();

    function animateParticles() {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      particles.forEach((p, i) => {
        p.x += p.vx;
        p.y += p.vy;
        if (p.x < 0 || p.x > canvas.width) p.vx *= -1;
        if (p.y < 0 || p.y > canvas.height) p.vy *= -1;

        ctx.beginPath();
        ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
        ctx.fillStyle = 'rgba(0, 180, 216, 0.5)';
        ctx.fill();

        for (let j = i + 1; j < particles.length; j++) {
          const dx = p.x - particles[j].x;
          const dy = p.y - particles[j].y;
          const dist = Math.sqrt(dx * dx + dy * dy);
          if (dist < CONNECT_DIST) {
            ctx.beginPath();
            ctx.moveTo(p.x, p.y);
            ctx.lineTo(particles[j].x, particles[j].y);
            ctx.strokeStyle = `rgba(0, 180, 216, ${0.15 * (1 - dist / CONNECT_DIST)})`;
            ctx.lineWidth = 0.6;
            ctx.stroke();
          }
        }
      });
      requestAnimationFrame(animateParticles);
    }
    animateParticles();
  }


  /* ---------- CARD TILT EFFECT ---------- */
  const tiltTargets = document.querySelectorAll('.project-card, .skill-card, .cert-card');
  const isTouchDevice = 'ontouchstart' in window;

  if (!isTouchDevice) {
    tiltTargets.forEach(card => {
      card.classList.add('tilt-card');
      card.addEventListener('mousemove', (e) => {
        const rect = card.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;
        const centerX = rect.width / 2;
        const centerY = rect.height / 2;
        const rotateX = ((y - centerY) / centerY) * -6;
        const rotateY = ((x - centerX) / centerX) * 6;
        card.style.transform = `perspective(600px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) translateY(-4px)`;
      });
      card.addEventListener('mouseleave', () => {
        card.style.transform = '';
      });
    });
  }


  /* ---------- STAGGERED SCROLL REVEAL ---------- */
  const staggerContainers = document.querySelectorAll('.skills-grid, .projects-grid, .certs-grid, .blog-grid');
  staggerContainers.forEach(container => {
    const children = container.children;
    for (let i = 0; i < children.length; i++) {
      const delay = Math.min(i, 4) + 1;
      children[i].classList.add(`reveal-delay-${delay}`);
    }
  });


  /* ---------- PARALLAX ON HERO ---------- */
  const heroText = document.querySelector('.hero-text');
  const heroVisual = document.querySelector('.hero-visual');
  if (heroText && heroVisual) {
    window.addEventListener('scroll', () => {
      const scrollY = window.scrollY;
      if (scrollY < window.innerHeight) {
        heroText.style.transform = `translateY(${scrollY * 0.15}px)`;
        heroVisual.style.transform = `translateY(${scrollY * 0.08}px)`;
      }
    });
  }


  /* ---------- DARK / LIGHT MODE TOGGLE ---------- */
  const themeToggle = document.querySelector('.theme-toggle');
  if (themeToggle) {
    const moonSVG = '<svg class="icon" viewBox="0 0 24 24"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>';
    const sunSVG = '<svg class="icon" viewBox="0 0 24 24"><circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/></svg>';

    // Sync icon with current state
    if (document.body.classList.contains('light-mode')) {
      themeToggle.innerHTML = sunSVG;
    }

    themeToggle.addEventListener('click', () => {
      document.body.classList.toggle('light-mode');
      const isLight = document.body.classList.contains('light-mode');
      themeToggle.innerHTML = isLight ? sunSVG : moonSVG;
      localStorage.setItem('theme', isLight ? 'light' : 'dark');
    });
  }


  /* ---------- BLOG TAG FILTER (Blog page only) ---------- */
  const blogFilterBtns = document.querySelectorAll('.blog-filter-btn');
  const blogCards = document.querySelectorAll('.blog-card');

  if (blogFilterBtns.length > 0) {
    blogFilterBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        const filter = btn.getAttribute('data-filter');

        blogFilterBtns.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');

        blogCards.forEach(card => {
          const category = card.getAttribute('data-category');
          if (filter === 'all' || category === filter) {
            card.classList.remove('hidden');
            card.style.animation = 'fadeIn 0.4s ease forwards';
          } else {
            card.classList.add('hidden');
          }
        });
      });
    });
  }


  /* ---------- READING PROGRESS BAR (Post pages) ---------- */
  const progressBar = document.querySelector('.reading-progress');
  if (progressBar) {
    window.addEventListener('scroll', () => {
      const docHeight = document.documentElement.scrollHeight - window.innerHeight;
      if (docHeight > 0) {
        const scrolled = Math.min((window.scrollY / docHeight) * 100, 100);
        progressBar.style.width = scrolled + '%';
      }
    });
  }

});

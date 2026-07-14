/* ============================================================
   Vanessa Awo — Portfolio JavaScript
   ============================================================ */

const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

if (location.hash === '#home') {
  history.replaceState(null, '', location.pathname + location.search);
}

document.addEventListener('DOMContentLoaded', () => {

  /* ---------- AOS (ANIMATE ON SCROLL) ---------- */
  if (typeof AOS !== 'undefined') {
    AOS.init({
      duration: prefersReducedMotion ? 0 : 400,
      easing: 'ease-out',
      once: true,
      offset: 60,
      disable: prefersReducedMotion ? true : 'mobile'
    });
  }


  /* ---------- PAGE LOADER ---------- */
  const pageLoader = document.getElementById('page-loader');
  if (pageLoader) {
    const minTime = 300;
    const startTime = performance.now();
    let dismissed = false;

    function dismissLoader() {
      if (dismissed) return;
      dismissed = true;
      const elapsed = performance.now() - startTime;
      const remaining = Math.max(0, minTime - elapsed);
      setTimeout(() => {
        pageLoader.classList.add('hidden');
        pageLoader.setAttribute('aria-hidden', 'true');
      }, remaining);
    }

    const hardCap = setTimeout(dismissLoader, 800);

    if (document.readyState === 'complete') {
      clearTimeout(hardCap);
      dismissLoader();
    } else {
      window.addEventListener('load', () => { clearTimeout(hardCap); dismissLoader(); });
      setTimeout(dismissLoader, 1200);
    }
  }


  /* ---------- SCROLL PROGRESS BAR ---------- */
  const scrollProgress = document.getElementById('scroll-progress');
  if (scrollProgress && !prefersReducedMotion) {
    window.addEventListener('scroll', () => {
      const docHeight = document.documentElement.scrollHeight - window.innerHeight;
      if (docHeight > 0) {
        scrollProgress.style.width = Math.min((window.scrollY / docHeight) * 100, 100) + '%';
      }
    }, { passive: true });
  }


  /* ---------- MOBILE NAVIGATION ---------- */
  const navToggle = document.getElementById('nav-toggle');
  const navMenu = document.getElementById('nav-menu');

  function openMenu() {
    navMenu.classList.add('open');
    navToggle.classList.add('open');
    navToggle.setAttribute('aria-expanded', 'true');
    navToggle.setAttribute('aria-label', 'Close menu');
  }

  function closeMenu() {
    navMenu.classList.remove('open');
    navToggle.classList.remove('open');
    navToggle.setAttribute('aria-expanded', 'false');
    navToggle.setAttribute('aria-label', 'Open menu');
  }

  if (navToggle && navMenu) {
    navToggle.addEventListener('click', () => {
      const isOpen = navMenu.classList.contains('open');
      if (isOpen) { closeMenu(); } else { openMenu(); }
    });

    document.querySelectorAll('.nav-link').forEach(link => {
      link.addEventListener('click', closeMenu);
    });

    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && navMenu.classList.contains('open')) {
        closeMenu();
        navToggle.focus();
      }
    });
  }


  /* ---------- CLEAN HASH URLS ---------- */
  document.querySelectorAll('a[href^="#"]').forEach(link => {
    link.addEventListener('click', e => {
      const hash = link.getAttribute('href');
      if (!hash || hash === '#') return;
      const target = document.querySelector(hash);
      if (target) {
        e.preventDefault();
        target.scrollIntoView({ behavior: prefersReducedMotion ? 'auto' : 'smooth' });
        history.replaceState(null, '', location.pathname + location.search);
      }
    });
  });


  /* ---------- NAVBAR SCROLL EFFECT ---------- */
  const navbar = document.getElementById('navbar');
  const backToTop = document.getElementById('back-to-top');
  const isInteriorPage = !document.querySelector('.hero');

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
      backToTop.classList.toggle('visible', window.scrollY > 500);
    }
  }, { passive: true });

  if (backToTop) {
    backToTop.addEventListener('click', () => {
      window.scrollTo({ top: 0, behavior: prefersReducedMotion ? 'auto' : 'smooth' });
    });
  }


  /* ---------- ACTIVE NAV LINK — PATHNAME-BASED ---------- */
  const navLinks = document.querySelectorAll('.nav-link');
  const path = window.location.pathname;

  const routeMap = {
    '/': 'Home',
    '/about/': 'About',
    '/projects/': 'Projects',
    '/experience/': 'Experience',
    '/certifications/': 'Certifications',
    '/blog/': 'Blog',
    '/architecture/': 'Architecture',
    '/contact/': 'Contact',
    '/skills/': 'Skills',
    '/demo/': 'Demo'
  };

  const normalizedPath = path.endsWith('/') ? path : path + '/';
  let currentPage = routeMap[normalizedPath] || '';

  if (!currentPage && path.includes('/posts/')) currentPage = 'Blog';
  if (!currentPage && (path === '/' || path === '' || normalizedPath === '/')) currentPage = 'Home';

  navLinks.forEach(link => {
    link.classList.remove('active');
    link.removeAttribute('aria-current');
    if (link.textContent.trim() === currentPage) {
      link.classList.add('active');
      link.setAttribute('aria-current', 'page');
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
      'certifications': 'Certifications',
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
                link.removeAttribute('aria-current');
                if (link.textContent.trim() === navLabel) {
                  link.classList.add('active');
                  link.setAttribute('aria-current', 'page');
                }
              });
            }
          }
        });
      }, { threshold: 0.15, rootMargin: '-80px 0px -40% 0px' });

      spySections.forEach(section => spyObserver.observe(section));
    }
  }


  /* ---------- COUNTER ANIMATION (Home page only) ---------- */
  const statNumbers = document.querySelectorAll('.stat-number');
  let countersAnimated = false;

  function animateCounters() {
    if (countersAnimated || prefersReducedMotion) return;

    statNumbers.forEach(stat => {
      const target = parseInt(stat.getAttribute('data-target'));
      if (isNaN(target)) return;
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
  if (heroStats && statNumbers.length > 0) {
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

        skillTabs.forEach(t => {
          t.classList.remove('active');
          t.setAttribute('aria-selected', 'false');
        });
        tab.classList.add('active');
        tab.setAttribute('aria-selected', 'true');

        skillPanels.forEach(panel => {
          panel.classList.remove('active');
          if (panel.id === `panel-${target}`) {
            panel.classList.add('active');
            if (!prefersReducedMotion) animateSkillBars(panel);
          }
        });
      });
    });
  }

  function animateSkillBars(container) {
    if (prefersReducedMotion) return;
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


  /* ---------- PROJECT FILTERS ---------- */
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
          if (filter === 'all' || category === filter || (card.getAttribute('data-tags') || '').includes(filter)) {
            card.classList.remove('hidden');
            if (!prefersReducedMotion) card.style.animation = 'fadeIn 0.4s ease forwards';
          } else {
            card.classList.add('hidden');
          }
        });
      });
    });

    if (!prefersReducedMotion) {
      const style = document.createElement('style');
      style.textContent = `@keyframes fadeIn { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: translateY(0); } }`;
      document.head.appendChild(style);
    }
  }


  /* ---------- SCROLL REVEAL ANIMATION ---------- */
  if (!prefersReducedMotion) {
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
  }


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


  /* ---------- PARTICLE NETWORK CANVAS ---------- */
  const heroSection = document.querySelector('.hero');
  if (heroSection && !prefersReducedMotion) {
    const canvas = document.createElement('canvas');
    canvas.id = 'particle-canvas';
    canvas.style.pointerEvents = 'none';
    canvas.setAttribute('aria-hidden', 'true');
    heroSection.appendChild(canvas);
    const ctx = canvas.getContext('2d');

    let particles = [];
    const isMobile = window.innerWidth < 768;
    const PARTICLE_COUNT = isMobile ? 20 : 45;
    const CONNECT_DIST = 110;

    function resizeCanvas() {
      canvas.width = heroSection.offsetWidth;
      canvas.height = heroSection.offsetHeight;
    }
    resizeCanvas();
    window.addEventListener('resize', resizeCanvas, { passive: true });

    function createParticles() {
      particles = [];
      for (let i = 0; i < PARTICLE_COUNT; i++) {
        particles.push({
          x: Math.random() * canvas.width,
          y: Math.random() * canvas.height,
          vx: (Math.random() - 0.5) * 0.5,
          vy: (Math.random() - 0.5) * 0.5,
          r: Math.random() * 1.5 + 1
        });
      }
    }
    createParticles();

    let animationId;
    function animateParticles() {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      particles.forEach((p, i) => {
        p.x += p.vx;
        p.y += p.vy;
        if (p.x < 0 || p.x > canvas.width) p.vx *= -1;
        if (p.y < 0 || p.y > canvas.height) p.vy *= -1;

        ctx.beginPath();
        ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
        ctx.fillStyle = 'rgba(0, 180, 216, 0.4)';
        ctx.fill();

        for (let j = i + 1; j < particles.length; j++) {
          const dx = p.x - particles[j].x;
          const dy = p.y - particles[j].y;
          const dist = Math.sqrt(dx * dx + dy * dy);
          if (dist < CONNECT_DIST) {
            ctx.beginPath();
            ctx.moveTo(p.x, p.y);
            ctx.lineTo(particles[j].x, particles[j].y);
            ctx.strokeStyle = `rgba(0, 180, 216, ${0.12 * (1 - dist / CONNECT_DIST)})`;
            ctx.lineWidth = 0.5;
            ctx.stroke();
          }
        }
      });
      animationId = requestAnimationFrame(animateParticles);
    }
    animateParticles();
  }


  /* ---------- CARD TILT EFFECT ---------- */
  const tiltTargets = document.querySelectorAll('.project-card, .skill-card, .cert-card');
  const isTouchDevice = 'ontouchstart' in window;

  if (!isTouchDevice && !prefersReducedMotion) {
    tiltTargets.forEach(card => {
      card.classList.add('tilt-card');
      card.addEventListener('mousemove', (e) => {
        const rect = card.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;
        const centerX = rect.width / 2;
        const centerY = rect.height / 2;
        const rotateX = ((y - centerY) / centerY) * -5;
        const rotateY = ((x - centerX) / centerX) * 5;
        card.style.transform = `perspective(600px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) translateY(-3px)`;
      });
      card.addEventListener('mouseleave', () => {
        card.style.transform = '';
      });
    });
  }


  /* ---------- STAGGERED SCROLL REVEAL ---------- */
  if (!prefersReducedMotion) {
    const staggerContainers = document.querySelectorAll('.skills-grid, .projects-grid, .certs-grid, .blog-grid');
    staggerContainers.forEach(container => {
      const children = container.children;
      for (let i = 0; i < children.length; i++) {
        const delay = Math.min(i, 4) + 1;
        children[i].classList.add(`reveal-delay-${delay}`);
      }
    });
  }


  /* ---------- PARALLAX ON HERO ---------- */
  const heroText = document.querySelector('.hero-text');
  const heroVisual = document.querySelector('.hero-visual');
  if (heroText && heroVisual && !prefersReducedMotion) {
    window.addEventListener('scroll', () => {
      const scrollY = window.scrollY;
      if (scrollY < window.innerHeight) {
        heroText.style.transform = `translateY(${scrollY * 0.12}px)`;
        heroVisual.style.transform = `translateY(${scrollY * 0.06}px)`;
      }
    }, { passive: true });
  }


  /* ---------- DARK / LIGHT MODE TOGGLE ---------- */
  const themeToggle = document.querySelector('.theme-toggle');
  if (themeToggle) {
    const moonSVG = '<svg class="icon" viewBox="0 0 24 24" aria-hidden="true"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>';
    const sunSVG = '<svg class="icon" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/></svg>';

    if (document.body.classList.contains('light-mode')) {
      themeToggle.innerHTML = sunSVG;
      themeToggle.setAttribute('aria-label', 'Switch to dark theme');
    }

    themeToggle.addEventListener('click', () => {
      document.body.classList.toggle('light-mode');
      const isLight = document.body.classList.contains('light-mode');
      themeToggle.innerHTML = isLight ? sunSVG : moonSVG;
      themeToggle.setAttribute('aria-label', isLight ? 'Switch to dark theme' : 'Switch to light theme');
      localStorage.setItem('theme', isLight ? 'light' : 'dark');
    });
  }


  /* ---------- BLOG TAG FILTER ---------- */
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
            if (!prefersReducedMotion) card.style.animation = 'fadeIn 0.4s ease forwards';
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
    }, { passive: true });
  }

});

import { initModals } from './main.js';

// Initialize functionality when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    // Check if user is logged in
    const user = JSON.parse(localStorage.getItem('user'));
    if (!user || !user.loggedIn) {
        // Redirect to login if not logged in
        window.location.href = '../auth/signin.html';
        return;
    }
    
    initModals();
    
    // Handle navigation between app pages
    const navLinks = document.querySelectorAll('.nav-link');
    navLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            e.preventDefault();
            const href = this.getAttribute('href');
            
            // Save checkbox states before navigating away from Preferences
            if (window.location.pathname.includes('preferences.html')) {
                saveCheckboxStates();
            }
            
            // In a real app, you would use client-side routing or page transitions
            // For now, we'll just navigate to the page
            window.location.href = href;
        });
    });
    
    // Load checkbox states on Preferences page
    if (window.location.pathname.includes('preferences.html')) {
        loadCheckboxStates();
        
        // Save checkbox states when they change
        const checkboxes = document.querySelectorAll('input[type="checkbox"]');
        checkboxes.forEach(checkbox => {
            checkbox.addEventListener('change', saveCheckboxStates);
        });
    }
});

// Function to save checkbox states to localStorage
function saveCheckboxStates() {
    const checkboxes = document.querySelectorAll('input[type="checkbox"]');
    const checkboxStates = {};
    
    checkboxes.forEach(checkbox => {
        checkboxStates[checkbox.id] = checkbox.checked;
    });
    
    localStorage.setItem('checkboxStates', JSON.stringify(checkboxStates));
}

// Function to load checkbox states from localStorage
function loadCheckboxStates() {
    const savedStates = JSON.parse(localStorage.getItem('checkboxStates'));
    
    if (savedStates) {
        const checkboxes = document.querySelectorAll('input[type="checkbox"]');
        checkboxes.forEach(checkbox => {
            if (savedStates.hasOwnProperty(checkbox.id)) {
                checkbox.checked = savedStates[checkbox.id];
            }
        });
    }
}
import { initModals, initProfilePage } from './main.js';

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
    initProfilePage();
});
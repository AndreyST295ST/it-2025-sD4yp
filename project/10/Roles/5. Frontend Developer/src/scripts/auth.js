// Simple authentication functionality
document.addEventListener('DOMContentLoaded', function() {
    // Handle sign up form submission
    const signupForm = document.querySelector('form.auth-form');
    if (signupForm && document.querySelector('#confirm-password')) {
        signupForm.addEventListener('submit', function(e) {
            e.preventDefault();
            const email = document.getElementById('email').value;
            const password = document.getElementById('password').value;
            const confirmPassword = document.getElementById('confirm-password').value;
            
            if (password !== confirmPassword) {
                alert('Passwords do not match!');
                return;
            }
            
            // In a real app, you would send this data to a server
            // For now, we'll just simulate successful registration
            alert('Account created successfully! You can now sign in.');
            window.location.href = 'signin.html';
        });
    }
    
    // Handle sign in form submission
    if (signupForm && !document.querySelector('#confirm-password')) {
        signupForm.addEventListener('submit', function(e) {
            e.preventDefault();
            const email = document.getElementById('email').value;
            const password = document.getElementById('password').value;
            
            // In a real app, you would verify these credentials with a server
            // For now, we'll just simulate successful login
            // Store user data in localStorage to simulate being logged in
            localStorage.setItem('user', JSON.stringify({
                email: email,
                loggedIn: true
            }));
            
            alert('Login successful!');
            window.location.href = '../app/explore.html';
        });
    }
    
    // Handle forgot password form submission
    if (signupForm && document.querySelector('#email') && !document.querySelector('#password')) {
        signupForm.addEventListener('submit', function(e) {
            e.preventDefault();
            const email = document.getElementById('email').value;
            
            // In a real app, you would send a reset link to this email
            // For now, we'll just simulate success
            window.location.href = 'reset-confirmation.html';
        });
    }
    
    // Handle new password form submission
    if (signupForm && document.querySelector('#new-password')) {
        signupForm.addEventListener('submit', function(e) {
            e.preventDefault();
            const newPassword = document.getElementById('new-password').value;
            const confirmPassword = document.getElementById('confirm-password').value;
            
            if (newPassword !== confirmPassword) {
                alert('Passwords do not match!');
                return;
            }
            
            // In a real app, you would update the user's password
            // For now, we'll just simulate success
            alert('Password updated successfully!');
            window.location.href = 'signin.html';
        });
    }
    
    // Check if user is logged in on app pages
    const appPages = ['explore.html', 'preferences.html', 'profile.html', 'game-detail.html'];
    const currentPage = window.location.pathname.split('/').pop();
    
    if (appPages.includes(currentPage)) {
        const user = JSON.parse(localStorage.getItem('user'));
        if (!user || !user.loggedIn) {
            // Redirect to login if not logged in
            window.location.href = '../auth/signin.html';
        }
    }
    
    // Handle sign out
    const signOutBtn = document.getElementById('sign-out');
    if (signOutBtn) {
        signOutBtn.addEventListener('click', function() {
            localStorage.removeItem('user');
            alert('You have been signed out.');
            window.location.href = '../auth/signin.html';
        });
    }
});
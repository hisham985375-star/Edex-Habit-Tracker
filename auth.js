// Check session on page load for protected routes
async function requireAuth(allowedRole = null) {
  const { data: { session }, error } = await db.auth.getSession();
  
  if (!session) {
    window.location.href = 'login.html';
    return null;
  }

  const user = session.user;

  if (allowedRole) {
    const { data: profile } = await db
      .from('profiles')
      .select('*')
      .eq('id', user.id)
      .single();
    
    if (!profile || profile.role !== allowedRole) {
      if (profile?.role === 'mentor') window.location.href = 'mentor_dashboard.html';
      else window.location.href = 'dashboard.html';
      return null;
    }
    return { user, profile };
  }

  return { user };
}

async function redirectIfLoggedIn() {
  const { data: { session } } = await db.auth.getSession();
  if (session) {
    const { data: profile } = await db
      .from('profiles')
      .select('*')
      .eq('id', session.user.id)
      .single();
      
    if (profile?.role === 'mentor') {
      window.location.href = 'mentor_dashboard.html';
    } else {
      window.location.href = 'dashboard.html';
    }
  }
}

async function handleLogout() {
  await db.auth.signOut();
  window.location.href = 'index.html';
}

// Automatically bind logout buttons if they exist
document.addEventListener('DOMContentLoaded', () => {
  const logoutBtns = document.querySelectorAll('.logout-btn');
  logoutBtns.forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.preventDefault();
      handleLogout();
    });
  });
});

function togglePassword(inputId, btn) {
  const input = document.getElementById(inputId);
  if (input.type === 'password') {
    input.type = 'text';
    btn.textContent = 'Hide';
  } else {
    input.type = 'password';
    btn.textContent = 'Show';
  }
}
